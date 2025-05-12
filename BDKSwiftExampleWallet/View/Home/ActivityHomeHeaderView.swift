//
//  TransactionListHeaderView.swift
//  BDKSwiftExampleWallet
//
//  Created by Rubens Machion on 24/04/25.
//

import SwiftUI
import BitcoinDevKit

struct ActivityHomeHeaderView: View {
    
    let walletSyncState: NodeState
    let progress: Float
    
    let showAllTransactions: () -> Void
    
    var body: some View {
        HStack {
            Text("Activity")
            Spacer()
            if !(walletSyncState == .transactionsSynced) {
                Text(
                    String(
                        format: "%.0f%%",
                        progress * 100
                    )
                )
                .contentTransition(.numericText())
                .transition(.opacity)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
                .font(.caption2)
                .fontWeight(.thin)
                .animation(.easeInOut, value: progress)
            }
            HStack {
                HStack(spacing: 5) {
                    self.syncImageIndicator()
                }
                .contentTransition(.symbolEffect(.replace.offUp))

            }
            .foregroundStyle(.secondary)
            .font(.caption)
            if walletSyncState == .transactionsSynced {
                Button {
                    self.showAllTransactions()
                } label: {
                    HStack(spacing: 2) {
                        Text("Show All")
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.regular)
                }
            }
        }
        .fontWeight(.bold)
    }
    
    @ViewBuilder
    private func syncImageIndicator() -> some View {
        switch walletSyncState {
        case .transactionsSynced:
            AnyView(
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            )
        default:
            AnyView(
                Image(systemName: "slowmo")
                    .symbolEffect(
                        .variableColor.cumulative
                    )
            )
        }
    }
}
