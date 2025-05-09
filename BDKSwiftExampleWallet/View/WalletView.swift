//
//  WalletView.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 5/23/23.
//

import BitcoinUI
import SwiftUI

struct WalletView: View {
    @AppStorage("balanceDisplayFormat") private var balanceFormat: BalanceDisplayFormat =
        .bitcoinSats
    @Bindable var viewModel: WalletViewModel
    @Binding var sendNavigationPath: NavigationPath
    @State private var isFirstAppear = true
    @State private var newTransactionSent = false
    @State private var showAllTransactions = false
    @State private var showReceiveView = false
    @State private var showSettingsView = false
    @State private var showingFormatMenu = false

    var body: some View {

        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {

                BalanceView(
                    format: balanceFormat,
                    balance: viewModel.balanceTotal,
                    fiatPrice: viewModel.price
                ).onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        balanceFormat =
                            BalanceDisplayFormat.allCases[
                                (balanceFormat.index + 1) % BalanceDisplayFormat.allCases.count
                            ]
                    }
                }

                VStack {
                    ActivityHomeHeaderView(
                        progress: viewModel.progress,
                    ) {
                        showAllTransactions = true
                    }
                    
                    TransactionListView(
                        viewModel: .init(),
                        transactions: viewModel.recentTransactions,
                    )

                    HStack {
                        Button {
                            showReceiveView = true
                        } label: {
                            Image(systemName: "qrcode")
                                .font(.title)
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        NavigationLink(value: NavigationDestination.address) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title)
                                .foregroundStyle(viewModel.canSend ? .primary : .secondary)
                        }
                        .disabled(!viewModel.canSend)
                    }
                    .padding([.horizontal, .bottom])

                }

            }
            .padding()
            .onReceive(
                NotificationCenter.default.publisher(for: Notification.Name("TransactionSent")),
                perform: { _ in
                    newTransactionSent = true
                }
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("AddressGenerated")
                ),
                perform: { _ in
                    Task {
                        viewModel.getBalance()
                        viewModel.getTransactions()
                        await viewModel.getPrices()
                    }
                }
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("WalletUpdated")
                ),
                perform: { _ in
                    Task {
                        viewModel.getBalance()
                        viewModel.getTransactions()
                        await viewModel.getPrices()
                    }
                }
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("ConnectionsChanged")
                ),
                perform: { _ in
                    Task {
                        viewModel.getNodeInfo()
                    }
                }
            )
            .task {
                viewModel.getBalance()
                if isFirstAppear || newTransactionSent {
                    isFirstAppear = false
                    newTransactionSent = false
                    viewModel.getBalance()
                }
                viewModel.getTransactions()
                await viewModel.getPrices()
            }

        }
        .navigationDestination(isPresented: $showAllTransactions) {
            ActivityListView(viewModel: .init())
        }
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .address:
                AddressView(navigationPath: $sendNavigationPath)
            case .amount(let address):
                AmountView(
                    viewModel: .init(),
                    navigationPath: $sendNavigationPath,
                    address: address
                )
            case .fee(let amount, let address):
                FeeView(
                    viewModel: .init(),
                    navigationPath: $sendNavigationPath,
                    address: address,
                    amount: amount
                )
            case .buildTransaction(let amount, let address, let fee):
                BuildTransactionView(
                    viewModel: .init(),
                    navigationPath: $sendNavigationPath,
                    address: address,
                    amount: amount,
                    fee: fee
                )
            }
        }
        .sheet(
            isPresented: $showReceiveView,
            onDismiss: {
                NotificationCenter.default.post(
                    name: Notification.Name("AddressGenerated"),
                    object: nil
                )
            }
        ) {
            ReceiveView(viewModel: .init())
        }
        .sheet(isPresented: $showSettingsView) {
            SettingsView(viewModel: .init())
        }
        .alert(isPresented: $viewModel.showingWalletViewErrorAlert) {
            Alert(
                title: Text("Wallet Error"),
                message: Text(viewModel.walletViewError?.description ?? "Unknown"),
                dismissButton: .default(Text("OK")) {
                    viewModel.walletViewError = nil
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if viewModel.connected {
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(.red)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettingsView = true
                } label: {
                    Image(systemName: "person.and.background.dotted")
                }
            }
        }
    }
}

#if DEBUG
    #Preview("WalletView - en") {
        WalletView(
            viewModel: .init(
                bdkClient: .mock,
                priceClient: .mock,
                transactions: [.mock],
            ),
            sendNavigationPath: .constant(.init())
        )
    }
#endif
