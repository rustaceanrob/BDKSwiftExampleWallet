//
//  KeyService.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 8/4/23.
//

import BitcoinDevKit
import Foundation
import KeychainAccess

private struct KeyService {
    private let keychain: Keychain

    init() {
        let keychain = Keychain(service: "com.robertnetzke.kyotoreferenceclient.testservice")
            .label(Bundle.main.displayName)
            .synchronizable(false)
            .accessibility(.whenUnlocked)
        self.keychain = keychain
    }

    func deleteBackupInfo() throws {
        try keychain.remove("BackupInfo")
    }

    func getBackupInfo() throws -> BackupInfo {
        guard let encryptedJsonData = try keychain.getData("BackupInfo") else {
            throw KeyServiceError.readError
        }
        let decoder = JSONDecoder()
        let backupInfo = try decoder.decode(BackupInfo.self, from: encryptedJsonData)
        return backupInfo
    }

    func saveBackupInfo(backupInfo: BackupInfo) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(backupInfo)
        keychain[data: "BackupInfo"] = data
    }
}

struct KeyClient {
    let deleteBackupInfo: () throws -> Void
    let getBackupInfo: () throws -> BackupInfo
    let saveBackupInfo: (BackupInfo) throws -> Void

    private init(
        deleteBackupInfo: @escaping () throws -> Void,
        getBackupInfo: @escaping () throws -> BackupInfo,
        saveBackupInfo: @escaping (BackupInfo) throws -> Void,
    ) {
        self.deleteBackupInfo = deleteBackupInfo
        self.getBackupInfo = getBackupInfo
        self.saveBackupInfo = saveBackupInfo
    }
}

extension KeyClient {
    static let live = Self(
        deleteBackupInfo: { try KeyService().deleteBackupInfo() },
        getBackupInfo: { try KeyService().getBackupInfo() },
        saveBackupInfo: { backupInfo in try KeyService().saveBackupInfo(backupInfo: backupInfo) },
    )
}

#if DEBUG
    extension KeyClient {
        static let mock = Self(
            deleteBackupInfo: { try KeyService().deleteBackupInfo() },
            getBackupInfo: {
                let words12 =
                    "space echo position wrist orient erupt relief museum myself grain wisdom tumble"
                let mnemonic = try Mnemonic.fromString(mnemonic: words12)
                let secretKey = DescriptorSecretKey(
                    network: mockKeyClientNetwork,
                    mnemonic: mnemonic,
                    password: nil
                )
                let descriptor = Descriptor.newBip86(
                    secretKey: secretKey,
                    keychainKind: .external,
                    network: mockKeyClientNetwork
                )
                let changeDescriptor = Descriptor.newBip86(
                    secretKey: secretKey,
                    keychainKind: .internal,
                    network: mockKeyClientNetwork
                )
                let backupInfo = BackupInfo(
                    descriptor: descriptor.description,
                    changeDescriptor: changeDescriptor.toStringWithSecret(),
                )
                return backupInfo
            },
            saveBackupInfo: { _ in },
        )
    }
#endif
