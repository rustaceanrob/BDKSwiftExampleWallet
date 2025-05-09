//
//  BackupInfo.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 8/5/23.
//

import Foundation

struct BackupInfo: Codable, Equatable {
    var descriptor: String
    var changeDescriptor: String

    init(descriptor: String, changeDescriptor: String) {
        self.descriptor = descriptor
        self.changeDescriptor = changeDescriptor
    }

    static func == (lhs: BackupInfo, rhs: BackupInfo) -> Bool {
        return lhs.descriptor == rhs.descriptor
            && lhs.changeDescriptor == rhs.changeDescriptor
    }
}

#if DEBUG
    extension BackupInfo {
        static var mock = Self(
            descriptor: "",
            changeDescriptor: "",
        )
    }
#endif
