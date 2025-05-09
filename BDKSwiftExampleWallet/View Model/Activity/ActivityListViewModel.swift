//
//  ActivityListViewModel.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 8/4/24.
//

import BitcoinDevKit
import Foundation

@MainActor
@Observable
class ActivityListViewModel {
    let bdkClient: BDKClient

    var displayMode: DisplayMode = .transactions
    var localOutputs: [LocalOutput] = []
    var transactions: [CanonicalTx]
    var showingWalletViewErrorAlert = false
    var walletViewError: AppError?

    enum DisplayMode {
        case transactions
        case outputs
    }

    init(
        bdkClient: BDKClient = .live,
        transactions: [CanonicalTx] = [],
        walletSyncState: WalletSyncState = .notStarted
    ) {
        self.bdkClient = bdkClient
        self.transactions = transactions
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

    func listUnspent() {
        do {
            self.localOutputs = try bdkClient.listUnspent()
        } catch let error as WalletError {
            self.walletViewError = .generic(message: error.localizedDescription)
            self.showingWalletViewErrorAlert = true
        } catch {
            self.walletViewError = .generic(message: error.localizedDescription)
            self.showingWalletViewErrorAlert = true
        }
    }
}
