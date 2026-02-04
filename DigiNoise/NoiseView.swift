//
//  NoiseViewModel.swift
//  DigiNoise
//
//  Main view model handling API calls and state
//

import SwiftUI
import Combine
import BackgroundTasks
import UserNotifications

@MainActor
class NoiseViewModel: ObservableObject {
    static let shared = NoiseViewModel()
    
    enum NoiseMode: String, CaseIterable {
        case background = "Background"
        
        var description: String {
            return "Makes automated web requests to public APIs from random global locations and topics."
        }
    }
    
    // MARK: - Published State
    @Published var isRunning = UserDefaults.standard.bool(forKey: "isRunning") {
        didSet {
            UserDefaults.standard.set(isRunning, forKey: "isRunning")
            if isRunning {
                scheduleBackgroundTasks()
            } else {
                cancelBackgroundTasks()
            }
        }
    }
    
    @Published var currentStatus = "Tap Start to begin"
    @Published var lastSearchDescription = "None" {
        didSet {
            UserDefaults.standard.set(lastSearchDescription, forKey: "lastSearchDescription")
        }
    }
    @Published var nextSearchTime: Date? {
        didSet {
            if let date = nextSearchTime {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "nextSearchTimeStamp")
            } else {
                UserDefaults.standard.removeObject(forKey: "nextSearchTimeStamp")
            }
        }
    }
    @Published var timeRemaining = "--:--:--"
    @Published var stats = SearchStats()
    
    @Published var stealthMode = UserDefaults.standard.bool(forKey: "stealthMode") {
        didSet { UserDefaults.standard.set(stealthMode, forKey: "stealthMode") }
    }
    
    @Published var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    
    // MARK: - Settings
    @Published var startHour: Int = UserDefaults.standard.integer(forKey: "startHour") == 0 ? 7 : UserDefaults.standard.integer(forKey: "startHour") {
        didSet { UserDefaults.standard.set(startHour, forKey: "startHour") }
    }
    
    @Published var endHour: Int = UserDefaults.standard.integer(forKey: "endHour") == 0 ? 23 : UserDefaults.standard.integer(forKey: "endHour") {
        didSet { UserDefaults.standard.set(endHour, forKey: "endHour") }
    }
    
    @Published var enabledCategories: Set<SearchGenerator.Category> = {
        if let data = UserDefaults.standard.data(forKey: "enabledCategories"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return Set(decoded.compactMap { SearchGenerator.Category(rawValue: $0) })
        }
        return Set(SearchGenerator.Category.allCases)
    }() {
        didSet {
            if let encoded = try? JSONEncoder().encode(enabledCategories.map { $0.rawValue }) {
                UserDefaults.standard.set(encoded, forKey: "enabledCategories")
            }
        }
    }
    
    @Published var enabledAPICategories: Set<APICategory> = {
        if let data = UserDefaults.standard.data(forKey: "enabledAPICategories"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return Set(decoded.compactMap { APICategory(rawValue: $0) })
        }
        return Set(APICategory.allCases)
    }() {
        didSet {
            if let encoded = try? JSONEncoder().encode(enabledAPICategories.map { $0.rawValue }) {
                UserDefaults.standard.set(encoded, forKey: "enabledAPICategories")
            }
        }
    }
    
    @Published var enabledAPILanguages: Set<APILanguage> = {
        if let data = UserDefaults.standard.data(forKey: "enabledAPILanguages"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return Set(decoded.compactMap { APILanguage(rawValue: $0) })
        }
        return Set(APILanguage.allCases)
    }() {
        didSet {
            if let encoded = try? JSONEncoder().encode(enabledAPILanguages.map { $0.rawValue }) {
                UserDefaults.standard.set(encoded, forKey: "enabledAPILanguages")
            }
        }
    }
    
    @Published var useCustomSchedule = UserDefaults.standard.bool(forKey: "useCustomSchedule") {
        didSet { UserDefaults.standard.set(useCustomSchedule, forKey: "useCustomSchedule") }
    }
    
    @Published var weeklySchedule: [DaySchedule] = {
        if let data = UserDefaults.standard.data(forKey: "weeklySchedule"),
           let decoded = try? JSONDecoder().decode([DaySchedule].self, from: data) {
            return decoded
        }
        return (1...7).map { DaySchedule(dayOfWeek: $0, isEnabled: true, startHour: 7, endHour: 23) }
    }() {
        didSet {
            if let encoded = try? JSONEncoder().encode(weeklySchedule) {
                UserDefaults.standard.set(encoded, forKey: "weeklySchedule")
            }
        }
    }
    
    @Published var dailyAPILimit: Int = UserDefaults.standard.integer(forKey: "dailyAPILimit") == 0 ? 3 : UserDefaults.standard.integer(forKey: "dailyAPILimit") {
        didSet {
            UserDefaults.standard.set(dailyAPILimit, forKey: "dailyAPILimit")
        }
    }
    
    var scheduleDisplayText: String {
        if !useCustomSchedule {
            return "\(startHour):00 - \(endHour):00 Daily"
        } else {
            let allEnabled = weeklySchedule.allSatisfy { $0.isEnabled }
            if allEnabled {
                let first = weeklySchedule.first!
                let sameHours = weeklySchedule.allSatisfy { $0.startHour == first.startHour && $0.endHour == first.endHour }
                if sameHours {
                    return "\(first.startHour):00 - \(first.endHour):00 Daily"
                }
            }
            return "Custom Schedule"
        }
    }
    
    // MARK: - Private Properties
    private var displayTimer: Timer?
    private var foregroundTimer: Timer?
    private var apiCallHistory: [String: Date] = [:]
    private let minimumAPIInterval: TimeInterval = 300
    private var consecutiveFailures: [String: Int] = [:]
    private let maxConsecutiveFailures = 3
    
    // MARK: - Initialization
    init() {
        loadStats()
        
        // Restore last search description
        if let savedDescription = UserDefaults.standard.string(forKey: "lastSearchDescription") {
            lastSearchDescription = savedDescription
        }
        
        // Restore persisted next search time using timestamp
        let savedTimestamp = UserDefaults.standard.double(forKey: "nextSearchTimeStamp")
        if savedTimestamp > 0 {
            let savedDate = Date(timeIntervalSince1970: savedTimestamp)
            if savedDate > Date() {
                nextSearchTime = savedDate
            } else {
                // Time has passed - clear it
                UserDefaults.standard.removeObject(forKey: "nextSearchTimeStamp")
            }
        }
        
        startDisplayTimer()
        
        if isRunning {
            scheduleBackgroundTasks()
            resumeOrSchedule()
        }
    }
    
    // MARK: - Public Methods
    func start() {
        isRunning = true
        scheduleNewSearch()
        scheduleBackgroundTasks()
        BackgroundTaskManager.shared.requestNotificationPermissions()
    }
    
    func stop() {
        isRunning = false
        foregroundTimer?.invalidate()
        foregroundTimer = nil
        nextSearchTime = nil
        currentStatus = "Stopped"
        timeRemaining = "--:--:--"
        cancelBackgroundTasks()
    }
    
    func resetStats() {
        stats = SearchStats()
        saveStats()
    }
    
    /// Called when app returns to foreground - resumes existing timer or executes if time passed
    func checkAutoResume() {
        let wasReset = stats.checkAndResetDaily()
        if wasReset {
            saveStats()
        }
        
        guard isRunning else { return }
        
        resumeOrSchedule()
    }
    
    /// Resumes countdown to existing target time, or schedules new if none exists
    private func resumeOrSchedule() {
        // Check daily limit first
        if stats.todaySearches >= dailyAPILimit {
            currentStatus = "Daily limit reached"
            timeRemaining = "Resets at midnight"
            nextSearchTime = nil
            foregroundTimer?.invalidate()
            scheduleCheckAtMidnight()
            return
        }
        
        // Check if we're in active hours
        guard isWithinActiveHours() else {
            updateStatusForInactiveHours()
            scheduleCheckForActiveHours()
            return
        }
        
        // If we have a persisted target time
        if let targetTime = nextSearchTime {
            let now = Date()
            
            if targetTime <= now {
                // Time has passed while we were in background - execute now!
                Task {
                    await performSearch()
                }
            } else {
                // Time hasn't passed yet - resume countdown
                resumeTimerToTarget(targetTime)
                updateStatus()
            }
        } else {
            // No target time exists - schedule a new one
            scheduleNewSearch()
        }
    }
    
    /// Schedules a brand new search with random interval
    private func scheduleNewSearch() {
        guard isRunning else { return }
        
        // Check daily limit
        if stats.todaySearches >= dailyAPILimit {
            currentStatus = "Daily limit reached"
            timeRemaining = "Resets at midnight"
            nextSearchTime = nil
            scheduleCheckAtMidnight()
            return
        }
        
        // Check schedule
        guard isWithinActiveHours() else {
            updateStatusForInactiveHours()
            scheduleCheckForActiveHours()
            return
        }
        
        // Random interval 1-6 hours
        let interval = TimeInterval.random(in: 3600...21600)
        let targetTime = Date().addingTimeInterval(interval)
        nextSearchTime = targetTime
        
        resumeTimerToTarget(targetTime)
        updateStatus()
    }
    
    /// Sets up timer to fire at specific target time
    private func resumeTimerToTarget(_ targetTime: Date) {
        foregroundTimer?.invalidate()
        
        let interval = targetTime.timeIntervalSince(Date())
        guard interval > 0 else {
            // Target already passed
            Task {
                await performSearch()
            }
            return
        }
        
        foregroundTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.performSearch()
            }
        }
    }
    
    // MARK: - Search Methods
    func performManualVisibleSearch() async {
        let query = SearchGenerator.generateQuery(enabledCategories: enabledCategories)
        await performSafariSearch(query: query)
        stats.addManualSearch(query: query)
        saveStats()
    }
    
    /// Called when foreground timer fires
    func performSearch() async {
        let wasReset = stats.checkAndResetDaily()
        if wasReset { saveStats() }
        
        // Clear the target time since we're executing
        nextSearchTime = nil
        
        if stats.todaySearches >= dailyAPILimit {
            scheduleNewSearch() // This will set the "daily limit reached" status
            return
        }
        
        currentStatus = "Making request..."
        
        let result = await performAPICall()
        
        if let endpoint = result.endpoint {
            let _ = stats.addSearch(
                query: endpoint.description,
                mode: "Background API",
                success: result.success,
                dataSize: result.dataSize,
                apiURL: endpoint.url,
                apiCategory: endpoint.category.rawValue,
                apiLanguage: endpoint.language?.rawValue
            )
            lastSearchDescription = endpoint.description
        }
        
        saveStats()
        
        // Schedule the next search
        scheduleNewSearch()
    }
    
    /// Called from background task (nonisolated for BGTask)
    nonisolated func performBackgroundSearch() async {
        // Check conditions on main actor
        let shouldRun = await MainActor.run {
            guard isRunning else { return false }
            
            let wasReset = stats.checkAndResetDaily()
            if wasReset { saveStats() }
            
            return stats.todaySearches < dailyAPILimit && isWithinActiveHours()
        }
        
        guard shouldRun else { return }
        
        // Perform the API call
        let result = await performAPICall()
        
        // Update state on main actor
        await MainActor.run {
            if let endpoint = result.endpoint {
                let _ = stats.addSearch(
                    query: endpoint.description,
                    mode: "Background API",
                    success: result.success,
                    dataSize: result.dataSize,
                    apiURL: endpoint.url,
                    apiCategory: endpoint.category.rawValue,
                    apiLanguage: endpoint.language?.rawValue
                )
                
                lastSearchDescription = endpoint.description
                saveStats()
                
                // Clear the next search time since we executed
                nextSearchTime = nil
                
                // Schedule a new target time
                if stats.todaySearches < dailyAPILimit && isWithinActiveHours() {
                    let interval = TimeInterval.random(in: 3600...21600)
                    nextSearchTime = Date().addingTimeInterval(interval)
                }
                
                // Send notification
                if !stealthMode {
                    BackgroundTaskManager.shared.sendBackgroundNotification(
                        title: "DigiNoise",
                        body: result.success ? "API: \(endpoint.description)" : "Request failed"
                    )
                }
            }
        }
    }
    
    // MARK: - Schedule Helpers
    private func scheduleCheckAtMidnight() {
        foregroundTimer?.invalidate()
        
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let midnight = calendar.date(bySettingHour: 0, minute: 1, second: 0, of: tomorrow) {
            let interval = midnight.timeIntervalSince(Date())
            foregroundTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.resumeOrSchedule()
                }
            }
        }
    }
    
    private func scheduleCheckForActiveHours() {
        foregroundTimer?.invalidate()
        
        // Check again in 10 minutes
        foregroundTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.resumeOrSchedule()
            }
        }
    }
    
    private func updateStatusForInactiveHours() {
        let (canRun, activeStart, _) = getScheduleInfo()
        if !canRun {
            currentStatus = "Day disabled in schedule"
            timeRemaining = "Check settings"
        } else {
            currentStatus = "Outside active hours"
            timeRemaining = "Resumes at \(activeStart):00"
        }
        nextSearchTime = nil
    }
    
    private func scheduleBackgroundTasks() {
        BackgroundTaskManager.shared.scheduleAppRefresh()
        BackgroundTaskManager.shared.scheduleProcessingTask()
    }
    
    private func cancelBackgroundTasks() {
        BackgroundTaskManager.shared.cancelAllTasks()
    }
    
    private func updateStatus() {
        if stats.todaySearches >= dailyAPILimit {
            currentStatus = "Daily limit reached"
            return
        }
        
        if !isWithinActiveHours() {
            updateStatusForInactiveHours()
            return
        }
        
        currentStatus = "Active"
    }
    
    private func isWithinActiveHours() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let (canRun, activeStart, activeEnd) = getScheduleInfo()
        return canRun && currentHour >= activeStart && currentHour < activeEnd
    }
    
    private func getScheduleInfo() -> (canRun: Bool, activeStart: Int, activeEnd: Int) {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: Date())
        
        if useCustomSchedule {
            if let todaySchedule = weeklySchedule.first(where: { $0.dayOfWeek == currentWeekday }) {
                return (todaySchedule.isEnabled, todaySchedule.startHour, todaySchedule.endHour)
            }
            return (false, 0, 0)
        }
        return (true, startHour, endHour)
    }
    
    private func performSafariSearch(query: String) async {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(encodedQuery)") {
            await UIApplication.shared.open(url)
        }
    }
    
    private func performAPICall() async -> (success: Bool, dataSize: Int64, endpoint: APIEndpoint?) {
        let endpoints = buildEndpointList()
        
        // Filter by enabled categories and languages
        let filtered = endpoints.filter { endpoint in
            let categoryMatch = enabledAPICategories.contains(endpoint.category)
            let languageMatch = endpoint.language == nil || enabledAPILanguages.contains(endpoint.language!)
            return categoryMatch && languageMatch
        }
        
        // Apply rate limiting
        let now = Date()
        let available = filtered.filter { endpoint in
            if let lastCall = apiCallHistory[endpoint.url] {
                if now.timeIntervalSince(lastCall) < minimumAPIInterval {
                    return false
                }
            }
            if let failures = consecutiveFailures[endpoint.url], failures >= maxConsecutiveFailures {
                if let lastCall = apiCallHistory[endpoint.url] {
                    let backoff = minimumAPIInterval * Double(failures)
                    if now.timeIntervalSince(lastCall) < backoff {
                        return false
                    }
                }
            }
            return true
        }
        
        guard !available.isEmpty else {
            print("No available endpoints (rate limiting)")
            return (false, 0, nil)
        }
        
        let endpoint = available.randomElement()!
        guard let url = URL(string: endpoint.url) else { return (false, 0, nil) }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("DigiNoise/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 15
            
            let (data, response) = try await URLSession.shared.data(for: request)
            let dataSize = Int64(data.count)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                await MainActor.run {
                    apiCallHistory[endpoint.url] = Date()
                    consecutiveFailures[endpoint.url] = 0
                    
                    if !stealthMode {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }
                return (true, dataSize, endpoint)
            }
            
            await MainActor.run {
                consecutiveFailures[endpoint.url, default: 0] += 1
            }
            return (false, 0, endpoint)
        } catch {
            await MainActor.run {
                consecutiveFailures[endpoint.url, default: 0] += 1
                apiCallHistory[endpoint.url] = Date()
            }
            print("API call failed: \(error.localizedDescription)")
            return (false, 0, endpoint)
        }
    }
    
    private func buildEndpointList() -> [APIEndpoint] {
        var endpoints: [APIEndpoint] = []
        
        // Wikipedia in all enabled languages
        for language in APILanguage.allCases {
            endpoints.append(APIEndpoint(
                url: "https://\(language.wikipediaCode).wikipedia.org/api/rest_v1/page/random/summary",
                category: .wikipedia,
                language: language,
                description: "\(language.rawValue) Wikipedia article"
            ))
        }
        
        // Weather endpoints
        let cities = [
            ("51.5074,-0.1278", "London"), ("35.6762,139.6503", "Tokyo"),
            ("40.7128,-74.0060", "NYC"), ("-33.8688,151.2093", "Sydney"),
            ("48.8566,2.3522", "Paris"), ("19.4326,-99.1332", "Mexico City"),
            ("-23.5505,-46.6333", "São Paulo"), ("55.7558,37.6173", "Moscow"),
            ("1.3521,103.8198", "Singapore"), ("25.2048,55.2708", "Dubai"),
            ("39.9042,116.4074", "Beijing"), ("28.6139,77.2090", "New Delhi"),
            ("37.5665,126.9780", "Seoul"), ("52.5200,13.4050", "Berlin")
        ]
        
        for (coords, city) in cities {
            let parts = coords.split(separator: ",")
            endpoints.append(APIEndpoint(
                url: "https://api.open-meteo.com/v1/forecast?latitude=\(parts[0])&longitude=\(parts[1])&current=temperature_2m",
                category: .weather,
                language: .english,
                description: "Weather in \(city)"
            ))
        }
        
        // Reddit endpoints
        let subreddits = ["worldnews", "books", "art", "photography", "cooking", "fitness",
                          "gardening", "travel", "sports", "science", "technology", "movies"]
        for sub in subreddits {
            endpoints.append(APIEndpoint(
                url: "https://www.reddit.com/r/\(sub).json?limit=1",
                category: .news,
                language: .english,
                description: "Reddit r/\(sub)"
            ))
        }
        
        // Other endpoints
        endpoints.append(contentsOf: [
            APIEndpoint(url: "https://hacker-news.firebaseio.com/v0/topstories.json", category: .technology, language: .english, description: "Hacker News"),
            APIEndpoint(url: "https://api.coindesk.com/v1/bpi/currentprice.json", category: .finance, language: .english, description: "Bitcoin price"),
            APIEndpoint(url: "https://api.spacexdata.com/v4/launches/latest", category: .science, language: .english, description: "SpaceX launch"),
            APIEndpoint(url: "https://api.github.com/events", category: .technology, language: .english, description: "GitHub events"),
            APIEndpoint(url: "https://dog.ceo/api/breeds/image/random", category: .animals, language: .english, description: "Random dog"),
            APIEndpoint(url: "https://catfact.ninja/fact", category: .animals, language: .english, description: "Cat fact"),
            APIEndpoint(url: "https://www.boredapi.com/api/activity", category: .entertainment, language: .english, description: "Activity suggestion"),
            APIEndpoint(url: "https://api.artic.edu/api/v1/artworks?limit=1", category: .art, language: .english, description: "Art Institute artwork"),
            APIEndpoint(url: "https://openlibrary.org/search.json?q=fiction&limit=1", category: .books, language: .english, description: "Fiction books"),
            APIEndpoint(url: "https://www.themealdb.com/api/json/v1/1/random.php", category: .food, language: .english, description: "Random recipe"),
            APIEndpoint(url: "https://www.thesportsdb.com/api/v1/json/3/all_sports.php", category: .sports, language: .english, description: "Sports list"),
            APIEndpoint(url: "https://api.quotable.io/random", category: .lifestyle, language: .english, description: "Random quote"),
        ])
        
        return endpoints
    }
    
    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimeRemaining()
            }
        }
    }
    
    private func updateTimeRemaining() {
        guard let nextTime = nextSearchTime else {
            // Don't overwrite status messages like "Daily limit reached"
            if currentStatus != "Daily limit reached" &&
               currentStatus != "Outside active hours" &&
               currentStatus != "Day disabled in schedule" &&
               !isRunning {
                timeRemaining = "--:--:--"
            }
            return
        }
        
        let remaining = nextTime.timeIntervalSince(Date())
        if remaining <= 0 {
            timeRemaining = "Processing..."
        } else {
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            let seconds = Int(remaining) % 60
            timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
    
    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(encoded, forKey: "searchStats")
        }
    }
    
    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: "searchStats"),
           let decoded = try? JSONDecoder().decode(SearchStats.self, from: data) {
            stats = decoded
        }
    }
    
    deinit {
        displayTimer?.invalidate()
        foregroundTimer?.invalidate()
    }
}
