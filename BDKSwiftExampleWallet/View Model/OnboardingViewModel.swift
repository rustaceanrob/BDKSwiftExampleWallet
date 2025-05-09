//
//  OnboardingViewModel.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 8/6/23.
//

import BitcoinDevKit
import Foundation
import SwiftUI

// Can't make @Observable yet
// https://developer.apple.com/forums/thread/731187
// Feature or Bug?
class OnboardingViewModel: ObservableObject {
    let keyClient: KeyClient

    @AppStorage("isOnboarding") var isOnboarding: Bool?

    @Published var applicationError: AppError?
    var isDescriptor: Bool {
        words.hasPrefix("tr(") || words.hasPrefix("wpkh(") || words.hasPrefix("wsh(")
            || words.hasPrefix("sh(")
    }
    @Published var networkColor = Color.gray
    @Published var onboardingViewError: AppError?
    @Published var words: String = ""
    var wordArray: [String] {
        if words.hasPrefix("tr(") || words.hasPrefix("wpkh(") || words.hasPrefix("wsh(") || words.hasPrefix("sh(") {
            return []
        }
        let trimmedWords = words.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedWords.components(separatedBy: " ")
    }
    var buttonColor: Color {
        #if DEBUG 
        return Constants.BitcoinNetworkColor.signet.color
        #else
        return Constants.BitcoinNetworkColor.bitcoin.color
        #endif
    }
    var network: Network {
        #if DEBUG
        return BitcoinDevKit.Network.signet
        #else
        return BitcoinDevKit.Network.bitcoin
        #endif
    }

    init(
        keyClient: KeyClient = .live
    ) {
        self.keyClient = keyClient
    }

    func createWallet() {
        do {
            let backupInfo = try deriveBackupInfo()
            try keyClient.saveBackupInfo(backupInfo)
            DispatchQueue.main.async {
                self.isOnboarding = false
            }
        } catch let error as KeyServiceError {
            DispatchQueue.main.async {
                self.applicationError = AppError.generic(message: error.localizedDescription)
            }
        } catch {
            DispatchQueue.main.async {
                self.onboardingViewError = .generic(message: error.localizedDescription)
            }
        }
    }
    
    func deriveBackupInfo() throws -> BackupInfo {
        if isDescriptor {
            let descriptorStrings = words.components(separatedBy: "\n")
                .map { $0.split(separator: "#").first?.trimmingCharacters(in: .whitespaces) ?? "" }
                .filter { !$0.isEmpty }
            let descriptor: Descriptor
            let changeDescriptor: Descriptor
            if descriptorStrings.count == 1 {
                let parsedDescriptor = try Descriptor(
                    descriptor: descriptorStrings[0],
                    network: network
                )
                let singleDescriptors = try parsedDescriptor.toSingleDescriptors()
                guard singleDescriptors.count >= 2 else {
                    throw AppError.generic(message: "Too many output descriptors to parse")
                }
                descriptor = singleDescriptors[0]
                changeDescriptor = singleDescriptors[1]
            } else if descriptorStrings.count == 2 {
                descriptor = try Descriptor(descriptor: descriptorStrings[0], network: network)
                changeDescriptor = try Descriptor(descriptor: descriptorStrings[1], network: network)
            } else {
                throw AppError.generic(message: "Descriptor parsing failed")
            }
            let backupInfo = BackupInfo(
                descriptor: descriptor.toStringWithSecret(),
                changeDescriptor: changeDescriptor.toStringWithSecret(),
            )
            isOnboarding = false
            return backupInfo
            
        } else {
            guard let mnemonic = try? Mnemonic.fromString(mnemonic: words) else {
                throw AppError.generic(message: "Invalid mnemonic")
            }
            let secretKey = DescriptorSecretKey(
                network: network,
                mnemonic: mnemonic,
                password: nil
            )
            let descriptor = Descriptor.newBip86(
                secretKey: secretKey,
                keychainKind: .external,
                network: network
            )
            let changeDescriptor = Descriptor.newBip86(
                secretKey: secretKey,
                keychainKind: .internal,
                network: network
            )
            let backupInfo = BackupInfo(
                descriptor: descriptor.toStringWithSecret(),
                changeDescriptor: changeDescriptor.toStringWithSecret(),
            )
            isOnboarding = false
            return backupInfo
        }
    }
}
