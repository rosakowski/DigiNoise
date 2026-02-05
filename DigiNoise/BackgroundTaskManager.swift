//
//  BackgroundTaskManager.swift
//  DigiNoise
//
//  Handles iOS background task scheduling and execution with persistent timing
//

import Foundation
import BackgroundTasks

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    static let backgroundTaskIdentifier = "com.diginoise.refresh"
    static let processingTaskIdentifier = "com.diginoise.processing"

    // Persistence keys
    private let nextFireTimeKey = "nextScheduledFireTime"
    private let dailyRequestCountKey = "dailyRequestCount"
    private let lastResetDateKey = "lastResetDate"

    private init() {}

    // MARK: - Registration

    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundTaskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.processingTaskIdentifier, using: nil) { task in
            self.handleProcessingTask(task: task as! BGProcessingTask)
        }

        print("[DigiNoise] Background tasks registered")
    }

    // MARK: - Public Scheduling API

    /// Call on app launch, foreground, and when settings change
    func syncSchedule() {
        guard UserDefaults.standard.bool(forKey: "isRunning") else {
            BGTaskScheduler.shared.cancelAllTaskRequests()
            clearPersistedSchedule()
            return
        }

        // Check if we need to reset daily counters
        checkAndResetDailyCounters()

        // Check if we missed a scheduled execution while suspended
        checkAndExecuteIfOverdue()

        // Ensure tasks are scheduled
        scheduleAppRefresh()
        scheduleProcessingTask()
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)

        // Use persisted next fire time if available, otherwise 15 minutes
        if let nextFire = getPersistedNextFireTime(), nextFire > Date() {
            request.earliestBeginDate = nextFire
        } else {
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        }

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[DigiNoise] Background app refresh scheduled for: \(request.earliestBeginDate ?? Date())")
        } catch {
            print("[DigiNoise] Could not schedule app refresh: \(error)")
        }
    }

    func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: Self.processingTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        // Schedule 5 minutes after refresh task for redundancy
        if let nextFire = getPersistedNextFireTime(), nextFire > Date() {
            request.earliestBeginDate = nextFire.addingTimeInterval(300)
        } else {
            request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        }

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[DigiNoise] Background processing task scheduled")
        } catch {
            print("[DigiNoise] Could not schedule processing task: \(error)")
        }
    }

    func cancelAllTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        clearPersistedSchedule()
        print("[DigiNoise] All background tasks cancelled")
    }

    // MARK: - Task Handlers

    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("[DigiNoise] App refresh task started")

        // Schedule the next refresh immediately
        scheduleAppRefresh()

        // Check if we should run
        guard shouldExecuteNow() else {
            task.setTaskCompleted(success: true)
            return
        }

        let operationTask = Task {
            await NoiseViewModel.shared.performBackgroundSearch()
        }

        task.expirationHandler = {
            operationTask.cancel()
            print("[DigiNoise] Background app refresh task expired")
        }

        Task {
            await operationTask.value
            task.setTaskCompleted(success: true)
            print("[DigiNoise] Background app refresh task completed")
        }
    }

    private func handleProcessingTask(task: BGProcessingTask) {
        print("[DigiNoise] Processing task started")

        // Schedule the next processing task
        scheduleProcessingTask()

        guard shouldExecuteNow() else {
            task.setTaskCompleted(success: true)
            return
        }

        let operationTask = Task {
            await NoiseViewModel.shared.performBackgroundSearch()
        }

        task.expirationHandler = {
            operationTask.cancel()
            print("[DigiNoise] Background processing task expired")
        }

        Task {
            await operationTask.value
            task.setTaskCompleted(success: true)
            print("[DigiNoise] Background processing task completed")
        }
    }

    // MARK: - Execution Logic

    private func shouldExecuteNow() -> Bool {
        guard UserDefaults.standard.bool(forKey: "isRunning") else { return false }

        checkAndResetDailyCounters()

        // Check daily limit
        let dailyLimit = UserDefaults.standard.integer(forKey: "dailyAPILimit")
        if dailyLimit > 0 && getDailyRequestCount() >= dailyLimit {
            return false
        }

        return isWithinActiveHours()
    }

    /// Check if scheduled time passed while app was suspended and execute if so
    private func checkAndExecuteIfOverdue() {
        guard let nextFire = getPersistedNextFireTime() else { return }
        guard UserDefaults.standard.bool(forKey: "isRunning") else { return }

        if Date() >= nextFire {
            print("[DigiNoise] Scheduled time passed while app was suspended - triggering catch-up")
            // Clear the overdue time
            clearPersistedSchedule()

            // Execute now (NoiseViewModel will handle scheduling the next one)
            Task {
                await NoiseViewModel.shared.performBackgroundSearch()
            }
        }
    }

    // MARK: - Active Hours

    private func isWithinActiveHours() -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        let useCustom = UserDefaults.standard.bool(forKey: "useCustomSchedule")

        if useCustom {
            let currentWeekday = calendar.component(.weekday, from: Date())
            if let data = UserDefaults.standard.data(forKey: "weeklySchedule"),
               let schedule = try? JSONDecoder().decode([DaySchedule].self, from: data),
               let todaySchedule = schedule.first(where: { $0.dayOfWeek == currentWeekday }) {
                guard todaySchedule.isEnabled else { return false }
                return hour >= todaySchedule.startHour && hour < todaySchedule.endHour
            }
            return false
        }

        let startHour = UserDefaults.standard.integer(forKey: "startHour")
        let endHour = UserDefaults.standard.integer(forKey: "endHour")

        // Handle overnight schedules (e.g., 22:00 - 06:00)
        if startHour > endHour {
            return hour >= startHour || hour < endHour
        }

        return hour >= startHour && hour < endHour
    }

    // MARK: - Daily Counter Management

    func checkAndResetDailyCounters() {
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

    // MARK: - Schedule Persistence

    func persistNextFireTime(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: nextFireTimeKey)
        print("[DigiNoise] Next fire time persisted: \(date)")
    }

    func getPersistedNextFireTime() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: nextFireTimeKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func clearPersistedSchedule() {
        UserDefaults.standard.removeObject(forKey: nextFireTimeKey)
    }
}
