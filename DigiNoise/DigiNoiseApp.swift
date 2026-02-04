//
//  DigiNoiseApp.swift
//  DigiNoise
//
//  App entry point with background task setup
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
        BackgroundTaskManager.shared.register()
        BackgroundTaskManager.shared.syncSchedule()
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundTaskManager.shared.syncSchedule()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        BackgroundTaskManager.shared.syncSchedule()
    }
}
