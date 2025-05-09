//
//  HomeViewModel.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 1/24/24.
//

import BitcoinDevKit
import Foundation

@MainActor
@Observable
class HomeViewModel: ObservableObject {
    let bdkClient: BDKClient

    var homeViewError: AppError?
    var isWalletLoaded = false
    var showingHomeViewErrorAlert = false

    init(bdkClient: BDKClient = .live) {
        self.bdkClient = bdkClient
    }
}
