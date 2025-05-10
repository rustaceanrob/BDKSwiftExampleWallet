//
//  TransactionListHeaderView.swift
//  BDKSwiftExampleWallet
//
//  Created by Rubens Machion on 24/04/25.
//

import SwiftUI

struct ActivityHomeHeaderView: View {
    
    let showAllTransactions: () -> Void
    
    var body: some View {
        HStack {
            Text("Activity")
            Spacer()
            HStack {
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
    
//    @ViewBuilder
//    private func syncImageIndicator() -> some View {
//        switch walletSyncState {
//        case .synced:
//            AnyView(
//                Image(systemName: "checkmark.circle.fill")
//                    .foregroundStyle(.green)
//            )
//            
//        case .syncing:
//            AnyView(
//                Image(systemName: "slowmo")
//                    .symbolEffect(
//                        .variableColor.cumulative
//                    )
//            )
//            
//        case .notStarted:
//            AnyView(
//                Image(systemName: "arrow.clockwise")
//            )
//        default:
//            AnyView(
//                Image(
//                    systemName: "person.crop.circle.badge.exclamationmark"
//                )
//            )
//        }
//    }
}
