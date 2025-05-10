//
//  WalletViewModel.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 8/6/23.
//

import BitcoinDevKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
class WalletViewModel {
    let bdkClient: BDKClient
    let keyClient: KeyClient
    let priceClient: PriceClient

    var balanceTotal: UInt64 = 0
    var canSend: Bool {
        guard let backupInfo = try? keyClient.getBackupInfo() else { return false }
        return backupInfo.descriptor.contains("tprv") || backupInfo.descriptor.contains("xprv")
    }
    var connected: Bool = false
    var price: Double = 0.00
    var progress: Float = 0.0
    var recentTransactions: [CanonicalTx] {
        let maxTransactions = UIScreen.main.isPhoneSE ? 4 : 5
        return Array(transactions.prefix(maxTransactions))
    }
    var satsPrice: Double {
        let usdValue = Double(balanceTotal).valueInUSD(price: price)
        return usdValue
    }
    var showingWalletViewErrorAlert = false
    var time: Int?
    var totalScripts: UInt64 = 0
    var transactions: [CanonicalTx]
    var walletViewError: AppError?


    init(
        bdkClient: BDKClient = .live,
        keyClient: KeyClient = .live,
        priceClient: PriceClient = .live,
        transactions: [CanonicalTx] = [],
    ) {
        self.bdkClient = bdkClient
        self.keyClient = keyClient
        self.priceClient = priceClient
        self.transactions = transactions
    }

    func getBalance() {
        let balance = bdkClient.getBalance()
        self.balanceTotal = balance.total.toSat()
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
    
    func getNodeInfo() {
        self.connected = bdkClient.isConnected()
        self.progress = bdkClient.getProgress()
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
}
