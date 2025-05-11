//
//  BDKSwiftExampleWalletApp.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 5/22/23.
//

import BitcoinDevKit
import BackgroundTasks
import SwiftUI

@main
struct BDKSwiftExampleWalletApp: App {
    @AppStorage("isOnboarding") var isOnboarding: Bool = true
    @State private var navigationPath = NavigationPath()
    
    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                if isOnboarding {
                    OnboardingView(viewModel: .init(keyClient: .live, bdkClient: .live))
                } else {
                    HomeView(viewModel: .init(bdkClient: .live), navigationPath: $navigationPath)
                }
            }
            .onChange(of: isOnboarding) { oldValue, newValue in
                navigationPath = NavigationPath()
            }
            .onAppear {
                let backupInfo = try? KeyClient.live.getBackupInfo()
                guard let backup = backupInfo else {
                    return
                }
                do {
                    let descriptor = try Descriptor(descriptor: backup.descriptor, network: NETWORK)
                    let changeDescriptor = try Descriptor(descriptor: backup.changeDescriptor, network: NETWORK)
                    let connection = try Connection.openConnection()
                    let wallet = try Wallet.load(descriptor: descriptor, changeDescriptor: changeDescriptor, connection: connection)
                    let cbf = try CbfBuilder()
                        .dataDir(dataDir: String.defaultDataDir())
                        .scanType(scanType: .sync)
                        .build(wallet: wallet)
                    BDKClient.live.setup(wallet, connection, cbf.client, cbf.node)
                    BDKClient.live.listen()
                } catch {
                    fatalError("Failed to start application")
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.didEnterBackgroundNotification
            ), perform: { _ in
                if !isOnboarding {
                    BDKClient.live.stop()
                    scheduleBackgroundSync()
                }
            })
        }
    }
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: .backgroundTaskName, using: nil) {
            (task) in
            self.handleBackgroundSync(task: task as! BGProcessingTask)
        }
    }
    
    func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: .backgroundTaskName)
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = true
        if let next3AM = Calendar.current.date(
            bySettingHour: 3, minute: 0, second: 0, of: Date().addingTimeInterval(60)
        ) {
            request.earliestBeginDate = next3AM
        }
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch  {
            #if DEBUG
            print("\(error)")
            #endif
        }
    }
    
    func handleBackgroundSync(task: BGProcessingTask) {
        scheduleBackgroundSync()
        let queue = OperationQueue()
        let semaphore = DispatchSemaphore(value: 0)
        var walletUpdate: Update?
        
        let operation = BlockOperation {
            do {
                guard let descriptor = UserDefaults.standard.string(forKey: "externalDescriptor") else { return }
                guard let change = UserDefaults.standard.string(forKey: "internalDescriptor") else { return }
                let externalDesc = try Descriptor(descriptor: descriptor, network: NETWORK)
                let internalDesc = try Descriptor(descriptor: change, network: NETWORK)
                let connection = try Connection.openConnection()
                let wallet = try Wallet.load(descriptor: externalDesc, changeDescriptor: internalDesc, connection: connection)
                let cbf = try CbfBuilder()
                    .dataDir(dataDir: String.defaultDataDir())
                    .scanType(scanType: .sync)
                    .build(wallet: wallet)
                let node = cbf.node
                node.run()
                let client = cbf.client
                Task {
                    let update = await client.update()
                    await MainActor.run {
                        walletUpdate = update
                    }
                    semaphore.signal()
                }
                semaphore.wait()
                guard let update = walletUpdate else {
                    return
                }
                try wallet.applyUpdate(update: update)
                let _ = try wallet.persist(connection: connection)
            } catch {}
        }
        
        queue.addOperation(operation)
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
                
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
    }
}
