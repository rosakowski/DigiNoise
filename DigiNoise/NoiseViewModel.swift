//
//  NoiseViewModel.swift
//  DigiNoise
//
//  Simplified view model - stripped complex stats
//

import SwiftUI
import BackgroundTasks

@MainActor
class NoiseViewModel: ObservableObject {
    static let shared = NoiseViewModel()
    
    // MARK: - Published State
    @Published var isRunning: Bool {
        didSet {
            UserDefaults.standard.set(isRunning, forKey: "isRunning")
            if isRunning {
                BackgroundTaskManager.shared.syncSchedule()
            } else {
                BackgroundTaskManager.shared.cancelAllTasks()
            }
        }
    }
    
    // MARK: - Settings
    @Published var startHour: Int {
        didSet { UserDefaults.standard.set(startHour, forKey: "startHour") }
    }
    
    @Published var endHour: Int {
        didSet { UserDefaults.standard.set(endHour, forKey: "endHour") }
    }
    
    @Published var dailyLimit: Int {
        didSet { UserDefaults.standard.set(dailyLimit, forKey: "dailyAPILimit") }
    }
    
    var dailyRequestCount: Int {
        BackgroundTaskManager.shared.getDailyRequestCount()
    }
    
    // MARK: - Private
    private var simpleStats: SimpleStats {
        didSet { saveStats() }
    }
    
    private let statsKey = "simpleStats"
    
    // MARK: - Initialization
    init() {
        self.isRunning = UserDefaults.standard.bool(forKey: "isRunning")
        self.startHour = UserDefaults.standard.integer(forKey: "startHour") == 0 ? 7 : UserDefaults.standard.integer(forKey: "startHour")
        self.endHour = UserDefaults.standard.integer(forKey: "endHour") == 0 ? 23 : UserDefaults.standard.integer(forKey: "endHour")
        self.dailyLimit = UserDefaults.standard.integer(forKey: "dailyAPILimit") == 0 ? 3 : UserDefaults.standard.integer(forKey: "dailyAPILimit")
        
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(SimpleStats.self, from: data) {
            self.simpleStats = decoded
        } else {
            self.simpleStats = SimpleStats()
        }
    }
    
    // MARK: - Public Methods
    
    func sync() {
        if isRunning {
            BackgroundTaskManager.shared.syncSchedule()
        }
    }
    
    func manualSafariSearch() async {
        let query = SearchGenerator.generate()
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
            await UIApplication.shared.open(url)
        }
    }
    
    /// Called from background tasks
    nonisolated func performBackgroundSearch() async {
        let shouldRun = await MainActor.run {
            guard isRunning else { return false }
            let count = BackgroundTaskManager.shared.getDailyRequestCount()
            return dailyLimit == 0 || count < dailyLimit
        }
        
        guard shouldRun else { return }
        
        let endpoint = getRandomEndpoint()
        guard let url = URL(string: endpoint.url) else { return }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("DigiNoise/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 15
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                await MainActor.run {
                    simpleStats.recordRequest()
                    BackgroundTaskManager.shared.incrementDailyRequestCount()
                }
                print("[DigiNoise] Background request successful: \(endpoint.description)")
            }
        } catch {
            print("[DigiNoise] Background request failed: \(error.localizedDescription)")
        }
    }
    
    func resetStats() {
        simpleStats = SimpleStats()
    }
    
    // MARK: - Private Methods
    
    private func getRandomEndpoint() -> APIEndpoint {
        let endpoints = [
            APIEndpoint(url: "https://en.wikipedia.org/api/rest_v1/page/random/summary", category: .wikipedia, description: "English Wikipedia"),
            APIEndpoint(url: "https://es.wikipedia.org/api/rest_v1/page/random/summary", category: .wikipedia, description: "Spanish Wikipedia"),
            APIEndpoint(url: "https://fr.wikipedia.org/api/rest_v1/page/random/summary", category: .wikipedia, description: "French Wikipedia"),
            APIEndpoint(url: "https://de.wikipedia.org/api/rest_v1/page/random/summary", category: .wikipedia, description: "German Wikipedia"),
            APIEndpoint(url: "https://api.open-meteo.com/v1/forecast?latitude=51.5074&longitude=-0.1278&current=temperature_2m", category: .weather, description: "London Weather"),
            APIEndpoint(url: "https://api.open-meteo.com/v1/forecast?latitude=35.6762&longitude=139.6503&current=temperature_2m", category: .weather, description: "Tokyo Weather"),
            APIEndpoint(url: "https://hacker-news.firebaseio.com/v0/topstories.json?limitToFirst=1", category: .tech, description: "Hacker News"),
            APIEndpoint(url: "https://www.reddit.com/r/worldnews.json?limit=1", category: .news, description: "World News"),
            APIEndpoint(url: "https://api.quotable.io/random", category: .entertainment, description: "Random Quote"),
        ]
        
        return endpoints.randomElement()!
    }
    
    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(simpleStats) {
            UserDefaults.standard.set(encoded, forKey: statsKey)
        }
    }
}
