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
    static let walletUpdated = Notification.Name("WalletUpdated")
}

extension Notification.Name {
    static let connectionsChanged = Notification.Name("ConnectionsChanged")
}

@Observable
private class BDKService {
    static var shared: BDKService = try! BDKService()
    
    private let connection: Connection
    private let keyClient: KeyClient
    private let wallet: Wallet
    private let client: CbfClient
    public var progress: Float = 0
    public var connected: Bool = false
    public var state: NodeState = .behind

    init(keyClient: KeyClient = .live) throws {
        self.keyClient = keyClient
        let backupInfo = try keyClient.getBackupInfo()
        let descriptor = try Descriptor(descriptor: backupInfo.descriptor, network: NETWORK)
        let changeDescriptor = try Descriptor(
            descriptor: backupInfo.changeDescriptor,
            network: NETWORK
        )
        let documentsDirectoryURL = URL.documentsDirectory
        let walletDataDirectoryURL = documentsDirectoryURL.appendingPathComponent("wallet_data")
        let persistenceBackendPath = walletDataDirectoryURL.appendingPathComponent("wallet.sqlite").path
        let databaseInitialized = FileManager.default.fileExists(atPath: persistenceBackendPath)
        if databaseInitialized {
            let connection = try Connection(path: persistenceBackendPath)
            self.connection = connection
            let wallet = try Wallet.load(
                descriptor: descriptor,
                changeDescriptor: changeDescriptor,
                connection: connection
            )
            self.wallet = wallet
        } else {
            self.connection = try Connection.createConnection()
            self.wallet = try Wallet(descriptor: descriptor, changeDescriptor: changeDescriptor, network: NETWORK, connection: self.connection)

        }
        let cbf = try! CbfBuilder()
            .dataDir(dataDir: walletDataDirectoryURL.path())
            .scanType(scanType: .new)
            .build(wallet: self.wallet)
        self.client = cbf.client
        cbf.node.run()
        continuallyUpdate()
        #if DEBUG
        printLogs()
        #endif
        updateInfo()
        updateWarn()
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

    func transactions() throws -> [CanonicalTx] {
        let transactions = wallet.transactions()
        let sortedTransactions = transactions.sorted { (tx1, tx2) in
            return tx1.chainPosition.isBefore(tx2.chainPosition)
        }
        return sortedTransactions
    }

    func listUnspent() throws -> [LocalOutput] {
        wallet.listUnspent()
    }

    func deleteWallet() throws {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        try self.keyClient.deleteBackupInfo()

        let documentsDirectoryURL = URL.documentsDirectory
        let walletDataDirectoryURL = documentsDirectoryURL.appendingPathComponent("wallet_data")
        if FileManager.default.fileExists(atPath: walletDataDirectoryURL.path) {
            try FileManager.default.removeItem(at: walletDataDirectoryURL)
        }
    }

    func getBackupInfo() throws -> BackupInfo {
        let backupInfo = try keyClient.getBackupInfo()
        return backupInfo
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
                    case .progress(progress: let prog): self.progress = prog
                    case .stateUpdate(nodeState: let state): self.state = state
                    case .txGossiped(wtxid: let txid): print("\(txid)")
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
    let deleteWallet: () throws -> Void
    let getBalance: () -> Balance
    let transactions: () throws -> [CanonicalTx]
    let listUnspent: () throws -> [LocalOutput]
    let getAddress: () throws -> String
    let send: (String, UInt64, UInt64) throws -> Void
    let calculateFee: (Transaction) throws -> Amount
    let calculateFeeRate: (Transaction) throws -> UInt64
    let sentAndReceived: (Transaction) throws -> SentAndReceivedValues
    let buildTransaction: (String, UInt64, UInt64) throws -> Psbt
    let getBackupInfo: () throws -> BackupInfo
    let getNetwork: () -> Network
    let isConnected: () -> Bool
}

extension BDKClient {
    static let live = Self(
        deleteWallet: { try BDKService.shared.deleteWallet() },
        getBalance: { BDKService.shared.getBalance() },
        transactions: { try BDKService.shared.transactions() },
        listUnspent: { try BDKService.shared.listUnspent() },
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
        getBackupInfo: { try BDKService.shared.getBackupInfo() },
        getNetwork: {
            BDKService.shared.getNetwork()
        },
        isConnected: { BDKService.shared.connected }
    )
}

#if DEBUG
    extension BDKClient {
        static let mock = Self(
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
            getBackupInfo: {
                BackupInfo(
                    descriptor:
                        "tr(tprv8ZgxMBicQKsPdXGCpRXi6PRsH2BaTpP2Aw4K7J5BLVEWHfXYfLZKsPh43VQncqSJucGj6KvzLTNayDcRJEKMfEqLGN1Pi3jjnM7mwRxGQ1s/86\'/1\'/0\'/0/*)#q4yvkz4r",
                    changeDescriptor:
                        "tr(tprv8ZgxMBicQKsPdXGCpRXi6PRsH2BaTpP2Aw4K7J5BLVEWHfXYfLZKsPh43VQncqSJucGj6KvzLTNayDcRJEKMfEqLGN1Pi3jjnM7mwRxGQ1s/86\'/1\'/0\'/1/*)#3ppdth9m",
                )
            },
            getNetwork: { return Network.signet },
            isConnected: { return true }
        )
    }
#endif
