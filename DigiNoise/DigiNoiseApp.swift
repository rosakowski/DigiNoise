//
//  DigiNoiseApp.swift
//  DigiNoise
//
//  Created by Ross Sakowski on 1/24/26.
//

import SwiftUI
import BackgroundTasks

@main
struct DigiNoiseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
        
        // If the app was running before, schedule background tasks
        if UserDefaults.standard.bool(forKey: "isRunning") {
            BackgroundTaskManager.shared.scheduleAppRefresh()
            BackgroundTaskManager.shared.scheduleProcessingTask()
        }
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background tasks when entering background
        if UserDefaults.standard.bool(forKey: "isRunning") {
            BackgroundTaskManager.shared.scheduleAppRefresh()
            BackgroundTaskManager.shared.scheduleProcessingTask()
        }
    }
}
