//
//  BDKSwiftExampleWalletApp.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 5/22/23.
//

import BitcoinDevKit
import SwiftUI

@main
struct BDKSwiftExampleWalletApp: App {
    @AppStorage("isOnboarding") var isOnboarding: Bool = true
    @State private var navigationPath = NavigationPath()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                let value = try? KeyClient.live.getBackupInfo()
                if value == nil {
                    OnboardingView(viewModel: .init(keyClient: .live))
                } else {
                    HomeView(viewModel: .init(bdkClient: .live), navigationPath: $navigationPath)
                }
            }
            .onChange(of: isOnboarding) { oldValue, newValue in
                navigationPath = NavigationPath()
            }
        }
    }
}
