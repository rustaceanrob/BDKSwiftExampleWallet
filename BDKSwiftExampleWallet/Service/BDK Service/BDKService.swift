//
//  BDKService.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 5/23/23.
//

import BitcoinDevKit
import Foundation

var NETWORK: Network {
    #if DEBUG
    return BitcoinDevKit.Network.signet
    #else
    return BitcoinDevKit.Network.bitcoin
    #endif
}

extension Notification.Name {
    static let walletUpdated = Notification.Name(.walletUpdatedNotification)

    static let connectionsChanged = Notification.Name(.connectionsChangedNotification)

    static let progressChanged = Notification.Name(.progressChangedNotification)
    
    static let transactionSent = Notification.Name(.transactionSentNotification)
}

private class BDKService {
    static var shared: BDKService = BDKService()
    
    struct Conf {
        let wallet: Wallet
        let connection: Connection
        let client: CbfClient
        let node: CbfNode
    }
    private static var conf: Conf?
    
    class func setup(_ conf: Conf) {
        BDKService.conf = conf
    }
    
    private let connection: Connection
    private let wallet: Wallet
    private let client: CbfClient
    private let node: CbfNode
    public var progress: Float = 0
    public var connected: Bool = false
    public var state: NodeState = .behind

    private init() {
        guard let conf = BDKService.conf else {
            fatalError("App error - singleton used before initialized")
        }
        self.client = conf.client
        self.wallet = conf.wallet
        self.node = conf.node
        self.connection = conf.connection
    }
    
    func getNetwork() -> Network {
        NETWORK
    }

    func getAddress() throws -> String {
        let addressInfo = wallet.revealNextAddress(keychain: .external)
        let _ = try wallet.persist(connection: connection)
        return addressInfo.address.description
    }

    func getBalance() -> Balance {
        wallet.balance()
    }

    func transactions() -> [CanonicalTx] {
        let transactions = wallet.transactions()
        let sortedTransactions = transactions.sorted { (tx1, tx2) in
            return tx1.chainPosition.isBefore(tx2.chainPosition)
        }
        return sortedTransactions
    }

    func listUnspent() -> [LocalOutput] {
        wallet.listUnspent()
    }

    func deleteWallet() throws {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        let documentsDirectoryURL = URL.documentsDirectory
        let walletDataDirectoryURL = documentsDirectoryURL.appendingPathComponent("wallet_data")
        if FileManager.default.fileExists(atPath: walletDataDirectoryURL.path) {
            try FileManager.default.removeItem(at: walletDataDirectoryURL)
        }
    }

    func send(
        address: String,
        amount: UInt64,
        feeRate: UInt64
    ) async throws {
        let psbt = try buildTransaction(
            address: address,
            amount: amount,
            feeRate: feeRate
        )
        try signAndBroadcast(psbt: psbt)
    }

    func buildTransaction(address: String, amount: UInt64, feeRate: UInt64) throws
        -> Psbt
    {
        let script = try Address(address: address, network: NETWORK)
            .scriptPubkey()
        let txBuilder = try TxBuilder()
            .addRecipient(
                script: script,
                amount: Amount.fromSat(satoshi: amount)
            )
            .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate))
            .finish(wallet: wallet)
        return txBuilder
    }

    private func signAndBroadcast(psbt: Psbt) throws {
        let isSigned = try wallet.sign(psbt: psbt)
        if isSigned {
            let transaction = try psbt.extractTx()
            try client.broadcast(transaction: transaction)
        } else {
            throw WalletError.notSigned
        }
    }

    func calculateFee(tx: Transaction) throws -> Amount {
        try wallet.calculateFee(tx: tx)
    }

    func calculateFeeRate(tx: Transaction) throws -> UInt64 {
        let feeRate = try wallet.calculateFeeRate(tx: tx)
        return feeRate.toSatPerVbCeil()
    }

    func sentAndReceived(tx: Transaction) throws -> SentAndReceivedValues {
        let values = wallet.sentAndReceived(tx: tx)
        return values
    }
    
    func listen() {
        node.run()
        continuallyUpdate()
        #if DEBUG
        printLogs()
        #endif
        updateInfo()
        updateWarn()
    }
    
    func stop() {
        let _ = try? client.shutdown()
    }
    
    private func continuallyUpdate() {
        Task {
            while true {
                let update = await self.client.update();
                try self.wallet.applyUpdate(update: update)
                let _ = try self.wallet.persist(connection: self.connection)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .walletUpdated, object: nil)
                }
            }
        }
    }
    
    private func printLogs() {
        Task {
            while true {
                if let log = try? await self.client.nextLog() {
                    print("\(log)")
                }
            }
        }
    }
    
    func updateInfo() {
        Task {
            while true {
                if let info = try? await self.client.nextInfo() {
                    switch info {
                    case .connectionsMet:
                        self.connected = true
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .connectionsChanged, object: nil)
                        }
                    case .progress(progress: let prog):
                        self.progress = prog
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .progressChanged, object: nil)
                        }
                    case .stateUpdate(nodeState: let state): self.state = state
                    case .txGossiped(wtxid: let wtxid):
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .transactionSent, object: nil)
                        }
                        #if DEBUG
                        print("WTXID: \(wtxid)")
                        #endif
                    }
                }
            }
        }
    }
    
    private func updateWarn() {
        Task {
            while true {
                if let warn = try? await self.client.nextWarning() {
                    switch warn {
                    case .needConnections:
                        self.connected = false
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .connectionsChanged, object: nil)
                        }
                    default:
                        #if DEBUG
                        print(warn)
                        #endif
                    
                    }
                }
            }
        }
    }
}

struct BDKClient {
    let setup: (Wallet, Connection, CbfClient, CbfNode) -> Void
    let listen: () -> Void
    let stop: () -> Void
    let deleteWallet: () throws -> Void
    let getBalance: () -> Balance
    let transactions: () -> [CanonicalTx]
    let listUnspent: () -> [LocalOutput]
    let getAddress: () throws -> String
    let send: (String, UInt64, UInt64) throws -> Void
    let calculateFee: (Transaction) throws -> Amount
    let calculateFeeRate: (Transaction) throws -> UInt64
    let sentAndReceived: (Transaction) throws -> SentAndReceivedValues
    let buildTransaction: (String, UInt64, UInt64) throws -> Psbt
    let getNetwork: () -> Network
    let isConnected: () -> Bool
    let getProgress: () -> Float
}

extension BDKClient {
    static let live = Self(
        setup: { (wallet, connection, client, node)
            in BDKService.setup(BDKService.Conf(wallet: wallet, connection: connection, client: client, node: node))
        },
        listen: { BDKService.shared.listen() },
        stop: { BDKService.shared.stop() },
        deleteWallet: { try BDKService.shared.deleteWallet() },
        getBalance: { BDKService.shared.getBalance() },
        transactions: { BDKService.shared.transactions() },
        listUnspent: { BDKService.shared.listUnspent() },
        getAddress: { try BDKService.shared.getAddress() },
        send: { (address, amount, feeRate) in
            Task {
                try await BDKService.shared.send(address: address, amount: amount, feeRate: feeRate)
            }
        },
        calculateFee: { tx in try BDKService.shared.calculateFee(tx: tx) },
        calculateFeeRate: { tx in try BDKService.shared.calculateFeeRate(tx: tx) },
        sentAndReceived: { tx in try BDKService.shared.sentAndReceived(tx: tx) },
        buildTransaction: { (address, amount, feeRate) in
            try BDKService.shared.buildTransaction(
                address: address,
                amount: amount,
                feeRate: feeRate
            )
        },
        getNetwork: {
            BDKService.shared.getNetwork()
        },
        isConnected: { BDKService.shared.connected },
        getProgress: { BDKService.shared.progress }
    )
}

#if DEBUG
    extension BDKClient {
        static let mock = Self(
            setup: { _, _, _, _ in return },
            listen: {},
            stop: {},
            deleteWallet: {},
            getBalance: { .mock },
            transactions: {
                return [
                    .mock
                ]
            },
            listUnspent: {
                return [
                    .mock
                ]
            },
            getAddress: { "tb1pd8jmenqpe7rz2mavfdx7uc8pj7vskxv4rl6avxlqsw2u8u7d4gfs97durt" },
            send: { _, _, _ in },
            calculateFee: { _ in Amount.fromSat(satoshi: UInt64(615)) },
            calculateFeeRate: { _ in return UInt64(6.15) },
            sentAndReceived: { _ in
                return SentAndReceivedValues(
                    sent: Amount.fromSat(satoshi: UInt64(20000)),
                    received: Amount.fromSat(satoshi: UInt64(210))
                )
            },
            buildTransaction: { _, _, _ in
                let pb64 = """
                    cHNidP8BAIkBAAAAAeaWcxp4/+xSRJ2rhkpUJ+jQclqocoyuJ/ulSZEgEkaoAQAAAAD+////Ak/cDgAAAAAAIlEgqxShDO8ifAouGyRHTFxWnTjpY69Cssr3IoNQvMYOKG/OVgAAAAAAACJRIGnlvMwBz4Ylb6xLTe5g4ZeZCxmVH/XWG+CDlcPzzaoT8qoGAAABAStAQg8AAAAAACJRIFGGvSoLWt3hRAIwYa8KEyawiFTXoOCVWFxYtSofZuAsIRZ2b8YiEpzexWYGt8B5EqLM8BE4qxJY3pkiGw/8zOZGYxkAvh7sj1YAAIABAACAAAAAgAAAAAAEAAAAARcgdm/GIhKc3sVmBrfAeRKizPAROKsSWN6ZIhsP/MzmRmMAAQUge7cvJMsJmR56NzObGOGkm8vNqaAIJdnBXLZD2PvrinIhB3u3LyTLCZkeejczmxjhpJvLzamgCCXZwVy2Q9j764pyGQC+HuyPVgAAgAEAAIAAAACAAQAAAAYAAAAAAQUgtIFPrI2EW/+PJiAmYdmux88p0KgeAxDFLMoeQoS66hIhB7SBT6yNhFv/jyYgJmHZrsfPKdCoHgMQxSzKHkKEuuoSGQC+HuyPVgAAgAEAAIAAAACAAAAAAAIAAAAA
                    """
                return try! Psbt(psbtBase64: pb64)
            },
            getNetwork: { return Network.signet },
            isConnected: { return true },
            getProgress: { 0.4 }
        )
    }
#endif
