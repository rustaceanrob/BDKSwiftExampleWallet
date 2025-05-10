//
//  TransactionListView.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 8/6/23.
//

import BitcoinDevKit
import BitcoinUI
import SwiftUI

struct TransactionListView: View {
    @Bindable var viewModel: TransactionListViewModel
    let transactions: [CanonicalTx]

    var body: some View {

        List {
            if transactions.isEmpty {
                VStack(alignment: .leading) {
                    Text("No Transactions")
                        .font(.subheadline)

                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

            } else {

                ForEach(
                    transactions,
                    id: \.transaction.transactionID
                ) { item in
                    let canonicalTx = item
                    let tx = canonicalTx.transaction
                    if let sentAndReceivedValues = viewModel.getSentAndReceived(tx: tx) {

                        NavigationLink(
                            destination: TransactionDetailView(
                                viewModel: .init(),
                                amount: sentAndReceivedValues.sent.toSat() == 0
                                    ? sentAndReceivedValues.received.toSat()
                                    : sentAndReceivedValues.sent.toSat()
                                        - sentAndReceivedValues.received.toSat(),
                                canonicalTx: canonicalTx
                            )
                        ) {
                            TransactionItemView(
                                canonicalTx: canonicalTx,
                                isRedacted: false,
                                sentAndReceivedValues: sentAndReceivedValues
                            )
                        }

                    } else {
                        Image(systemName: "questionmark")
                    }

                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            }

        }
        .listStyle(.plain)
        .alert(isPresented: $viewModel.showingWalletTransactionsViewErrorAlert) {
            Alert(
                title: Text("Wallet Transaction Error"),
                message: Text(viewModel.walletTransactionsViewError?.description ?? "Unknown"),
                dismissButton: .default(Text("OK")) {
                    viewModel.walletTransactionsViewError = nil
                }
            )
        }

    }

}

#if DEBUG
    #Preview {
        TransactionListView(
            viewModel: .init(
                bdkClient: .mock
            ),
            transactions: [
                .mock
            ],
        )
    }
#endif
