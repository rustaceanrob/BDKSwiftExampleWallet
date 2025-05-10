//
//  OnboardingView.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 5/23/23.
//

import BitcoinDevKit
import BitcoinUI
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showingOnboardingViewErrorAlert = false
    @State private var showingImportView = false
    @State private var showingScanner = false
    let pasteboard = UIPasteboard.general
    var isSmallDevice: Bool {
        UIScreen.main.isPhoneSE
    }
    @State private var animateContent = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack {
                HStack(alignment: .center, spacing: 40) {
                    Spacer()

                    if viewModel.words.isEmpty {
                        Button {
                            showingScanner = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                                .transition(.symbolEffect(.disappear))
                        }
                        .tint(.secondary)
                        .font(.title)
                        .opacity(animateContent ? 1 : 0)
                        .offset(x: animateContent ? 0 : 100)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7).delay(1.2),
                            value: animateContent
                        )

                        Button {
                            if let clipboardContent = UIPasteboard.general.string {
                                viewModel.words = clipboardContent
                            }
                        } label: {
                            Image(systemName: "arrow.down.square")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .tint(.secondary)
                        .font(.title)
                        .opacity(animateContent ? 1 : 0)
                        .offset(x: animateContent ? 0 : 100)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7).delay(1.3),
                            value: animateContent
                        )
                    } else {
                        Button {
                            viewModel.words = ""
                        } label: {
                            Image(systemName: "clear")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .tint(.primary)
                        .font(.title)
                    }
                }
                .padding()

                Spacer()

                VStack(spacing: isSmallDevice ? 5 : 25) {
                    if viewModel.words.isEmpty {
                        Image(systemName: "bitcoinsign.circle")
                            .resizable()
                            .foregroundStyle(.secondary)
                            .frame(
                                width: isSmallDevice ? 40 : 100,
                                height: isSmallDevice ? 40 : 100,
                                alignment: .center
                            )
                            .scaleEffect(animateContent ? 1 : 0)
                            .opacity(animateContent ? 1 : 0)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0.6),
                                value: animateContent
                            )
                    }
                    Text("Hacked by 2140")
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.secondary, .primary]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .fontWidth(.expanded)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .padding()
                        .opacity(animateContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.6), value: animateContent)
                }
                .padding()

                if !viewModel.words.isEmpty {
                    if viewModel.isDescriptor {
                        Text(viewModel.words)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding()
                    } else {
                        SeedPhraseView(
                            words: viewModel.wordArray,
                            preferredWordsPerRow: 2,
                            usePaging: true,
                            wordsPerPage: 4
                        )
                        .frame(
                            height: isSmallDevice ? 150 : 200
                        )
                        .padding()
                    }
                }

                Spacer()
                if viewModel.words.isEmpty {
                    Button("New Wallet") {
                        if viewModel.words.isEmpty {
                            let words = Mnemonic(wordCount: WordCount.words12)
                            viewModel.words = words.description
                        }
                    }
                    .buttonStyle(
                        BitcoinFilled(
                            tintColor: .primary,
                            textColor: Color(uiColor: .systemBackground),
                            isCapsule: true
                        )
                    )
                    .padding()
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 50)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7).delay(1.2),
                        value: animateContent
                    )
                    .contentTransition(.numericText())
                } else {
                    Button("Create Wallet") {
                        viewModel.createWallet()
                    }
                    .buttonStyle(
                        BitcoinFilled(
                            tintColor: .primary,
                            textColor: Color(uiColor: .systemBackground),
                            isCapsule: true
                        )
                    )
                    .padding()
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 50)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7).delay(1.2),
                        value: animateContent
                    )
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: animateContent)

                }
            }
        }
        .alert(isPresented: $showingOnboardingViewErrorAlert) {
            Alert(
                title: Text("Onboarding Error"),
                message: Text(viewModel.onboardingViewError?.description ?? "Unknown"),
                dismissButton: .default(Text("OK")) {
                    viewModel.onboardingViewError = nil
                }
            )
        }
        .sheet(isPresented: $showingScanner) {
            CustomScannerView(
                codeTypes: [.qr],
                completion: { result in
                    switch result {
                    case .success(let result):
                        viewModel.words = result.string
                        showingScanner = false
                    case .failure(let error):
                        viewModel.onboardingViewError = .generic(
                            message: error.localizedDescription
                        )
                        showingScanner = false
                    }
                },
                pasteAction: {}
            )
        }
        .onAppear {
            withAnimation {
                animateContent = true
            }
        }
    }
}

#if DEBUG
    #Preview("OnboardingView - en") {
        OnboardingView(viewModel: .init(keyClient: .mock))
    }
#endif
