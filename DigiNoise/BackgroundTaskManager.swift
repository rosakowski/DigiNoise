//
//  BackgroundTaskManager.swift
//  DigiNoise
//
//  Handles iOS background task scheduling and execution
//

import Foundation
import BackgroundTasks
import UserNotifications

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    static let backgroundTaskIdentifier = "com.diginoise.refresh"
    static let processingTaskIdentifier = "com.diginoise.processing"
    
    private init() {}
    
    func registerBackgroundTasks() {
        // Register app refresh task (runs frequently but briefly)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundTaskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Register processing task (runs less frequently but can run longer)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.processingTaskIdentifier, using: nil) { task in
            self.handleProcessingTask(task: task as! BGProcessingTask)
        }
        
        print("Background tasks registered")
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes minimum
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background app refresh scheduled for earliest: \(request.earliestBeginDate ?? Date())")
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: Self.processingTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour minimum
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background processing task scheduled")
        } catch {
            print("Could not schedule processing task: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh immediately
        scheduleAppRefresh()
        
        // Check if we should run
        guard UserDefaults.standard.bool(forKey: "isRunning") else {
            task.setTaskCompleted(success: true)
            return
        }
        
        // Create the async operation
        let operationTask = Task {
            await NoiseViewModel.shared.performBackgroundSearch()
        }
        
        // Handle expiration
        task.expirationHandler = {
            operationTask.cancel()
            print("Background app refresh task expired")
        }
        
        // Complete when done
        Task {
            await operationTask.value
            task.setTaskCompleted(success: true)
            print("Background app refresh task completed")
        }
    }
    
    private func handleProcessingTask(task: BGProcessingTask) {
        // Schedule the next processing task
        scheduleProcessingTask()
        
        guard UserDefaults.standard.bool(forKey: "isRunning") else {
            task.setTaskCompleted(success: true)
            return
        }
        
        let operationTask = Task {
            await NoiseViewModel.shared.performBackgroundSearch()
        }
        
        task.expirationHandler = {
            operationTask.cancel()
            print("Background processing task expired")
        }
        
        Task {
            await operationTask.value
            task.setTaskCompleted(success: true)
            print("Background processing task completed")
        }
    }
    
    func cancelAllTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        print("All background tasks cancelled")
    }
    
    // MARK: - Notification Helpers
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func sendBackgroundNotification(title: String, body: String) {
        guard !UserDefaults.standard.bool(forKey: "stealthMode") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil // Silent
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
