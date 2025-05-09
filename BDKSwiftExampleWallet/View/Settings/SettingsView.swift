//
//  SettingsView.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 1/24/24.
//

import BitcoinUI
import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var isSeedPresented = false
    @State private var showingDeleteSeedConfirmation = false
    @State private var showingShowSeedConfirmation = false
    var isSmallDevice: Bool {
        UIScreen.main.isPhoneSE
    }

    var body: some View {

        NavigationStack {

            HStack {
                Text("Profile".uppercased())
                    .font(.body)
                    .padding()
                Spacer()
            }
            .padding(.horizontal, 10.0)
            .padding(.top, 40.0)
            .padding(.bottom, -40.0)
            .foregroundStyle(.secondary)

            Form {

                Section(header: Text("Network")) {
                    let network = NETWORK.description
                    Text("\(network)")
                }
                .listRowBackground(
                    colorScheme == .light ? Color.gray.opacity(0.1) : Color.black.opacity(0.2)
                )

                Section(header: Text("Danger Zone")) {
                    Button {
                        showingShowSeedConfirmation = true
                    } label: {
                        Text(String(localized: "Show Wallet"))
                            .foregroundStyle(.red)
                    }
                }
                .listRowBackground(
                    colorScheme == .light ? Color.gray.opacity(0.1) : Color.black.opacity(0.2)
                )

                Section(header: Text("Destructive Zone")) {
                    Button {
                        showingDeleteSeedConfirmation = true
                    } label: {
                        HStack {
                            Text(String(localized: "Delete Wallet"))
                                .foregroundStyle(.red)
                        }
                    }
                }
                .listRowBackground(
                    colorScheme == .light ? Color.gray.opacity(0.1) : Color.black.opacity(0.2)
                )

            }
            .background(Color(uiColor: UIColor.systemBackground))
            .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .onAppear {
                viewModel.getNetwork()
            }
            .padding(.top, 40.0)

        }
        .sheet(isPresented: $isSeedPresented) {
            WalletRecoveryView(viewModel: .init())
                .presentationDetents(isSmallDevice ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            "Are you sure you want to view the seed?",
            isPresented: $showingShowSeedConfirmation
        ) {
            Button("Yes", role: .destructive) {
                isSeedPresented = true
            }
            Button("No", role: .cancel) {}
        }
        .alert(
            "Are you sure you want to delete the seed?",
            isPresented: $showingDeleteSeedConfirmation
        ) {
            Button("Yes", role: .destructive) {
                viewModel.delete()
                dismiss()
            }
            Button("No", role: .cancel) {}
        }
        .alert(isPresented: $viewModel.showingSettingsViewErrorAlert) {
            Alert(
                title: Text("Settings Error"),
                message: Text(viewModel.settingsError?.description ?? "Unknown"),
                dismissButton: .default(Text("OK")) {
                    viewModel.settingsError = nil
                }
            )
        }
    }
}

#if DEBUG
    #Preview {
        SettingsView(
            viewModel: .init(
                bdkClient: .mock
            )
        )
    }
#endif
