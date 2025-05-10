import BitcoinDevKit
import Foundation

extension Connection {
    static func createConnection() throws -> Connection {
        let documentsDirectoryURL = URL.documentsDirectory
        let walletDataDirectoryURL = documentsDirectoryURL.appendingPathComponent("wallet_data")

        if FileManager.default.fileExists(atPath: walletDataDirectoryURL.path) {
            try FileManager.default.removeItem(at: walletDataDirectoryURL)
        }

        try FileManager.default.ensureDirectoryExists(at: walletDataDirectoryURL)
        let persistenceBackendPath = walletDataDirectoryURL.appendingPathComponent("wallet.sqlite")
            .path
        let connection = try Connection(path: persistenceBackendPath)
        return connection
    }
    
    static func openConnection() throws -> Connection {
        let documentsDirectoryURL = URL.documentsDirectory
        let walletDataDirectoryURL = documentsDirectoryURL.appendingPathComponent("wallet_data")
        let persistenceBackendPath = walletDataDirectoryURL.appendingPathComponent("wallet.sqlite")
            .path
        let connection = try Connection(path: persistenceBackendPath)
        return connection
    }
}
