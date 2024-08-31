//
//  WalletViewModel.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 8/6/23.
//

import BitcoinDevKit
import Foundation
import Observation

@MainActor
@Observable
class WalletViewModel {
    let priceClient: PriceClient
    let bdkClient: BDKClient

    var balanceTotal: UInt64 = 0
    var walletSyncState: WalletSyncState
    var transactions: [CanonicalTx]
    var price: Double = 0.00
    var time: Int?
    var satsPrice: Double {
        let usdValue = Double(balanceTotal).valueInUSD(price: price)
        return usdValue
    }
    var walletViewError: AppError?
    var showingWalletViewErrorAlert = false

    var progress: Float = 0.0
    var inspectedScripts: UInt64 = 0
    var totalScripts: UInt64 = 0

    var recentTransactions: [CanonicalTx] {
        Array(transactions.prefix(5))
    }

    init(
        priceClient: PriceClient = .live,
        bdkClient: BDKClient = .live,
        walletSyncState: WalletSyncState = .notStarted,
        transactions: [CanonicalTx] = []
    ) {
        self.priceClient = priceClient
        self.bdkClient = bdkClient
        self.walletSyncState = walletSyncState
        self.transactions = transactions
    }

    func getPrices() async {
        do {
            let price = try await priceClient.fetchPrice()
            self.price = price.usd
            self.time = price.time
        } catch {
            self.walletViewError = .generic(message: error.localizedDescription)
            self.showingWalletViewErrorAlert = true
        }
    }

    func getBalance() {
        do {
            let balance = try bdkClient.getBalance()
            self.balanceTotal = balance.total.toSat()
        } catch let error as WalletError {
            self.walletViewError = .generic(message: error.localizedDescription)
            self.showingWalletViewErrorAlert = true
        } catch {
            self.walletViewError = .generic(message: error.localizedDescription)
            self.showingWalletViewErrorAlert = true
        }
    }

    func getTransactions() {
        do {
            let transactionDetails = try bdkClient.transactions()
            self.transactions = transactionDetails
        } catch let error as WalletError {
            self.walletViewError = .generic(message: error.localizedDescription)
            self.showingWalletViewErrorAlert = true
        } catch {
            self.walletViewError = .generic(message: error.localizedDescription)
            self.showingWalletViewErrorAlert = true
        }
    }

    func startSyncWithProgress(logger: MessageHandler) async {
        self.walletSyncState = .syncing
        Task {
            while true {
                try await bdkClient.sync(logger)
                self.walletSyncState = .synced
                self.getBalance()
                self.getTransactions()
            }
        }
    }

    private func updateProgress(inspected: UInt64, total: UInt64) {
        DispatchQueue.main.async {
            self.totalScripts = total
            self.inspectedScripts = inspected
            self.progress = total > 0 ? Float(inspected) / Float(total) : 0
        }
    }

    private func updateProgressFullScan(inspected: UInt64) {
        DispatchQueue.main.async {
            self.inspectedScripts = inspected
        }
    }

}

class WalletSyncScriptInspector: SyncScriptInspector {
    private let updateProgress: (UInt64, UInt64) -> Void
    private var inspectedCount: UInt64 = 0
    private var totalCount: UInt64 = 0

    init(updateProgress: @escaping (UInt64, UInt64) -> Void) {
        self.updateProgress = updateProgress
    }

    func inspect(script: Script, total: UInt64) {
        totalCount = total
        inspectedCount += 1
        updateProgress(inspectedCount, totalCount)
    }
}

class WalletFullScanScriptInspector: FullScanScriptInspector {
    private let updateProgress: (UInt64) -> Void
    private var inspectedCount: UInt64 = 0

    init(updateProgress: @escaping (UInt64) -> Void) {
        self.updateProgress = updateProgress
    }

    func inspect(keychain: KeychainKind, index: UInt32, script: Script) {
        inspectedCount += 1
        updateProgress(inspectedCount)
    }
}

class MessageHandler: ObservableObject, NodeMessageHandler {
    @Published var progress: Double = 20
    @Published var height: UInt32? = nil
    
    func blocksDisconnected(blocks: [UInt32]) {}
    
    func connectionsMet() {}
    
    func dialog(dialog: String) {
        print(dialog)
    }
    
    func stateChanged(state: BitcoinDevKit.NodeState) {
        DispatchQueue.main.async { [self] in
            switch state {
            case .behind:
                progress = 20
            case .headersSynced:
                progress = 40
            case .filterHeadersSynced:
                progress = 60
            case .filtersSynced:
                progress = 80
            case .transactionsSynced:
                progress = 100
            }
        }
    }
    
    func synced(tip: UInt32) {
        print("Synced to \(tip)")
    }
    
    func txFailed(txid: BitcoinDevKit.Txid) {}
    
    func txSent(txid: BitcoinDevKit.Txid) {}
    
    func warning(warning: BitcoinDevKit.Warning) {
        switch warning {
        case .notEnoughConnections:
            print("Searching for connections")
        case .peerTimedOut:
            print("A peer timed out")
        case .unsolicitedMessage:
            print("A peer sent an unsolicited message")
        case .couldNotConnect:
            print("The node reached out to a peer and could not connect")
        case .corruptedHeaders:
            print("The loaded headers do not link together")
        case .transactionRejected:
            print("A transaction was rejected")
        case .failedPersistance(warning: let warning):
            print(warning)
        case .evaluatingFork:
            print("Evaluating a potential fork")
        case .emptyPeerDatabase:
            print("The peer database is empty")
        case .unexpectedSyncError(warning: let warning):
            print(warning)
        case .noCompactFilters:
            print("A connected peer does not serve compact block filters")
        case .potentialStaleTip:
            print("The node has not seen a new block for a long duration")
        case .unlinkableAnchor:
            print("The configured recovery does not link to block headers stored in the database")
        }
    }
}

