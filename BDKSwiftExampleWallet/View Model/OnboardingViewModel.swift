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
    let bdkClient: BDKClient

    @AppStorage("isOnboarding") var isOnboarding: Bool?
    @AppStorage("externalDescriptor") var externalDescriptor: String?
    @AppStorage("internalDescriptor") var internalDescriptor: String?

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

    init(
        keyClient: KeyClient = .live,
        bdkClient: BDKClient = .live
    ) {
        self.keyClient = keyClient
        self.bdkClient = bdkClient
    }
    
    func getNewWords() {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            do {
                let trng_words = try Mnemonic.fromEntropy(entropy: Data(bytes))
                self.words = trng_words.description
            } catch {
                self.onboardingViewError = .generic(message: error.localizedDescription)
            }
        }
    }

    func createWallet() {
        do {
            let backupInfo = try buildWallet()
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
    
    func saveDesciptorBackup(descriptor: Descriptor, changeDescriptor: Descriptor) -> BackupInfo {
        externalDescriptor = descriptor.description
        internalDescriptor = changeDescriptor.description
        let backupInfo = BackupInfo(
            descriptor: descriptor.toStringWithSecret(),
            changeDescriptor: changeDescriptor.toStringWithSecret(),
        )
        return backupInfo
    }
    
    func initializeWallet(desriptor: Descriptor, changeDescriptor: Descriptor) throws -> (Wallet, Connection) {
        let connection = try Connection.createConnection()
        let wallet = try Wallet(descriptor: desriptor, changeDescriptor: changeDescriptor, network: NETWORK, connection: connection)
        return (wallet, connection)
    }
    
    func buildNode(wallet: Wallet) throws -> CbfComponents {
        let componenets = try CbfBuilder()
            .dataDir(dataDir: String.defaultDataDir())
            .logLevel(logLevel: LOG_LEVEL)
            .scanType(scanType: .recovery(fromHeight: TAPROOT_HEIGHT))
            .build(wallet: wallet)
        return componenets
    }
    
    func buildWallet() throws -> BackupInfo {
        if isDescriptor {
            let descriptorStrings = words.components(separatedBy: "\n")
                .map { $0.split(separator: "#").first?.trimmingCharacters(in: .whitespaces) ?? "" }
                .filter { !$0.isEmpty }
            let descriptor: Descriptor
            let changeDescriptor: Descriptor
            if descriptorStrings.count == 1 {
                let parsedDescriptor = try Descriptor(
                    descriptor: descriptorStrings[0],
                    network: NETWORK
                )
                let singleDescriptors = try parsedDescriptor.toSingleDescriptors()
                guard singleDescriptors.count >= 2 else {
                    throw AppError.generic(message: "Too many output descriptors to parse")
                }
                descriptor = singleDescriptors[0]
                changeDescriptor = singleDescriptors[1]
            } else if descriptorStrings.count == 2 {
                descriptor = try Descriptor(descriptor: descriptorStrings[0], network: NETWORK)
                changeDescriptor = try Descriptor(descriptor: descriptorStrings[1], network: NETWORK)
            } else {
                throw AppError.generic(message: "Descriptor parsing failed")
            }
            let backupInfo = saveDesciptorBackup(descriptor: descriptor, changeDescriptor: changeDescriptor)
            let (wallet, connection) = try initializeWallet(desriptor: descriptor, changeDescriptor: changeDescriptor)
            let cbf = try buildNode(wallet: wallet)
            bdkClient.setup(wallet, connection, cbf.client, cbf.node)
            bdkClient.listen()
            return backupInfo
            
        } else {
            guard let mnemonic = try? Mnemonic.fromString(mnemonic: words) else {
                throw AppError.generic(message: "Invalid mnemonic")
            }
            let secretKey = DescriptorSecretKey(
                network: NETWORK,
                mnemonic: mnemonic,
                password: nil
            )
            let descriptor = Descriptor.newBip86(
                secretKey: secretKey,
                keychainKind: .external,
                network: NETWORK
            )
            let changeDescriptor = Descriptor.newBip86(
                secretKey: secretKey,
                keychainKind: .internal,
                network: NETWORK
            )
            let backupInfo = saveDesciptorBackup(descriptor: descriptor, changeDescriptor: changeDescriptor)
            let (wallet, connection) = try initializeWallet(desriptor: descriptor, changeDescriptor: changeDescriptor)
            let cbf = try buildNode(wallet: wallet)
            bdkClient.setup(wallet, connection, cbf.client, cbf.node)
            bdkClient.listen()
            return backupInfo
        }
    }
}
