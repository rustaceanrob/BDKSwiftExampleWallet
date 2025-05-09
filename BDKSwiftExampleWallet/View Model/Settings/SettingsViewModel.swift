//
//  SettingsViewModel.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 1/24/24.
//

import BitcoinDevKit
import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    let bdkClient: BDKClient

    @AppStorage("isOnboarding") var isOnboarding: Bool = true
    @Published var network: String?
    @Published var settingsError: AppError?
    @Published var showingSettingsViewErrorAlert = false

    init(
        bdkClient: BDKClient = .live
    ) {
        self.bdkClient = bdkClient
        self.network = bdkClient.getNetwork().description
    }

    func delete() {
        do {
            try bdkClient.deleteWallet()
            isOnboarding = true
        } catch {
            self.settingsError = .generic(message: error.localizedDescription)
            self.showingSettingsViewErrorAlert = true
        }
    }


    func getNetwork() {
        self.network = bdkClient.getNetwork().description
    }
}
