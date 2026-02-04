//
//  BackgroundTaskManager.swift
//  DigiNoise
//
//  Simplified background task scheduling with persisted timing
//

import Foundation
import BackgroundTasks

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    static let refreshTaskIdentifier = "com.diginoise.refresh"
    static let processingTaskIdentifier = "com.diginoise.processing"
    
    private let nextFireTimeKey = "nextScheduledFireTime"
    private let dailyRequestCountKey = "dailyRequestCount"
    private let lastResetDateKey = "lastResetDate"
    
    private init() {}
    
    // MARK: - Registration
    
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskIdentifier, using: nil) { task in
            self.handleRefresh(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.processingTaskIdentifier, using: nil) { task in
            self.handleProcessing(task: task as! BGProcessingTask)
        }
        
        print("[DigiNoise] Background tasks registered")
    }
    
    // MARK: - Public API
    
    /// Call on app launch, foreground, and background transitions
    func syncSchedule() {
        guard UserDefaults.standard.bool(forKey: "isRunning") else {
            BGTaskScheduler.shared.cancelAllTaskRequests()
            clearPersistedSchedule()
            return
        }
        
        // Check if we need to reset daily counters
        checkAndResetDailyCounters()
        
        // Check if we missed a scheduled execution
        checkAndExecuteIfOverdue()
        
        // Schedule the next task
        scheduleNextTask()
    }
    
    func cancelAllTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        clearPersistedSchedule()
    }
    
    // MARK: - Scheduling Logic
    
    private func scheduleNextTask() {
        // Check daily limit
        let dailyLimit = UserDefaults.standard.integer(forKey: "dailyAPILimit")
        guard dailyLimit == 0 || getDailyRequestCount() < dailyLimit else {
            print("[DigiNoise] Daily limit reached, not scheduling")
            return
        }
        
        // Check active hours
        guard isWithinActiveHours() else {
            print("[DigiNoise] Outside active hours, scheduling check for later")
            scheduleActiveHoursCheck()
            return
        }
        
        // Calculate next fire time (random 1-6 hours)
        let interval = TimeInterval.random(in: 3600...21600)
        let nextFire = Date().addingTimeInterval(interval)
        
        persistNextFireTime(nextFire)
        
        // Submit both task types for redundancy
        submitRefreshTask(earliestDate: nextFire)
        submitProcessingTask(earliestDate: nextFire.addingTimeInterval(300)) // 5 min after refresh
        
        print("[DigiNoise] Next execution scheduled for \(nextFire)")
    }
    
    private func submitRefreshTask(earliestDate: Date) {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = earliestDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[DigiNoise] Failed to schedule refresh: \(error)")
        }
    }
    
    private func submitProcessingTask(earliestDate: Date) {
        let request = BGProcessingTaskRequest(identifier: Self.processingTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = earliestDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[DigiNoise] Failed to schedule processing: \(error)")
        }
    }
    
    private func scheduleActiveHoursCheck() {
        // Schedule a check in 30 minutes to see if we're back in active hours
        let checkTime = Date().addingTimeInterval(1800)
        submitRefreshTask(earliestDate: checkTime)
    }
    
    // MARK: - Task Handlers
    
    private func handleRefresh(task: BGAppRefreshTask) {
        print("[DigiNoise] Refresh task started")
        
        // Always schedule next task first
        scheduleNextTask()
        
        guard shouldExecuteNow() else {
            task.setTaskCompleted(success: true)
            return
        }
        
        let operation = Task {
            await NoiseViewModel.shared.performBackgroundSearch()
        }
        
        task.expirationHandler = {
            operation.cancel()
            print("[DigiNoise] Refresh task expired")
        }
        
        Task {
            await operation.value
            task.setTaskCompleted(success: true)
            print("[DigiNoise] Refresh task completed")
        }
    }
    
    private func handleProcessing(task: BGProcessingTask) {
        print("[DigiNoise] Processing task started")
        
        scheduleNextTask()
        
        guard shouldExecuteNow() else {
            task.setTaskCompleted(success: true)
            return
        }
        
        let operation = Task {
            await NoiseViewModel.shared.performBackgroundSearch()
        }
        
        task.expirationHandler = {
            operation.cancel()
        }
        
        Task {
            await operation.value
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - Execution Logic
    
    private func shouldExecuteNow() -> Bool {
        guard UserDefaults.standard.bool(forKey: "isRunning") else { return false }
        
        checkAndResetDailyCounters()
        
        let dailyLimit = UserDefaults.standard.integer(forKey: "dailyAPILimit")
        if dailyLimit > 0 && getDailyRequestCount() >= dailyLimit {
            return false
        }
        
        return isWithinActiveHours()
    }
    
    private func checkAndExecuteIfOverdue() {
        guard let nextFire = getPersistedNextFireTime() else { return }
        
        if Date() >= nextFire {
            print("[DigiNoise] Scheduled time passed while app was suspended - executing now")
            Task {
                await NoiseViewModel.shared.performBackgroundSearch()
                scheduleNextTask()
            }
        }
    }
    
    // MARK: - Schedule Helpers
    
    private func isWithinActiveHours() -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        let startHour = UserDefaults.standard.integer(forKey: "startHour")
        let endHour = UserDefaults.standard.integer(forKey: "endHour")
        
        // Handle overnight schedules (e.g., 22:00 - 06:00)
        if startHour > endHour {
            return hour >= startHour || hour < endHour
        }
        
        return hour >= startHour && hour < endHour
    }
    
    private func checkAndResetDailyCounters() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastReset = UserDefaults.standard.object(forKey: lastResetDateKey) as? Date,
           calendar.startOfDay(for: lastReset) < today {
            UserDefaults.standard.set(0, forKey: dailyRequestCountKey)
            UserDefaults.standard.set(Date(), forKey: lastResetDateKey)
            print("[DigiNoise] Daily counters reset")
        } else if UserDefaults.standard.object(forKey: lastResetDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: lastResetDateKey)
        }
    }
    
    func incrementDailyRequestCount() {
        let current = getDailyRequestCount()
        UserDefaults.standard.set(current + 1, forKey: dailyRequestCountKey)
    }
    
    func getDailyRequestCount() -> Int {
        checkAndResetDailyCounters()
        return UserDefaults.standard.integer(forKey: dailyRequestCountKey)
    }
    
    // MARK: - Persistence
    
    private func persistNextFireTime(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: nextFireTimeKey)
    }
    
    private func getPersistedNextFireTime() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: nextFireTimeKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    private func clearPersistedSchedule() {
        UserDefaults.standard.removeObject(forKey: nextFireTimeKey)
    }
}
