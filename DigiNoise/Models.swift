//
//  Models.swift
//  DigiNoise
//
//  Data models for DigiNoise app
//

import Foundation

// MARK: - Search Generator with Category Support
struct SearchGenerator {
    enum Category: String, CaseIterable, Identifiable, Codable {
        case cooking = "Cooking & Food"
        case fitness = "Health & Fitness"
        case creative = "Arts & Crafts"
        case tech = "Technology"
        case lifestyle = "Lifestyle"
        case learning = "Education"
        case outdoor = "Outdoor Activities"
        case travel = "Travel & Culture"
        case finance = "Finance & Business"
        case home = "Home & Garden"
        case entertainment = "Entertainment"
        case fashion = "Fashion & Beauty"
        case sports = "Sports & Recreation"
        case science = "Science & Nature"
        case automotive = "Automotive"
        case pets = "Pets & Animals"
        case music = "Music & Audio"
        case gaming = "Gaming & Esports"
        case diy = "DIY & Crafts"
        case wellness = "Wellness & Mindfulness"
        
        var id: String { rawValue }
        
        var topics: [String] {
            switch self {
            case .cooking: return ["recipe", "baking", "cooking", "nutrition", "meal prep", "food photography", "culinary arts", "wine pairing", "fermentation", "sous vide", "grilling", "vegan cooking", "pastry", "sourdough", "meal planning"]
            case .fitness: return ["fitness", "yoga", "running", "cycling", "swimming", "meditation", "health", "strength training", "HIIT", "pilates", "marathon training", "CrossFit", "calisthenics", "stretching", "cardio"]
            case .creative: return ["painting", "drawing", "photography", "writing", "music", "pottery", "knitting", "sculpture", "calligraphy", "watercolor", "digital art", "sketching", "illustration", "printmaking", "ceramics"]
            case .tech: return ["coding", "technology", "gaming", "AI", "web development", "apps", "cybersecurity", "machine learning", "blockchain", "data science", "cloud computing", "programming", "software engineering", "3D printing"]
            case .lifestyle: return ["fashion", "interior design", "gardening", "minimalism", "organizing", "home decor", "sustainable living", "zero waste", "apartment living", "feng shui", "decluttering", "productivity"]
            case .learning: return ["language learning", "education", "books", "history", "science", "psychology", "philosophy", "online courses", "studying techniques", "memory improvement", "speed reading", "public speaking"]
            case .outdoor: return ["hiking", "camping", "fishing", "birdwatching", "travel", "wildlife", "backpacking", "rock climbing", "kayaking", "trail running", "mountaineering", "nature photography", "foraging", "astronomy"]
            case .travel: return ["travel planning", "budget travel", "solo travel", "cultural experiences", "language immersion", "street food", "travel photography", "backpacking", "luxury travel", "road trips", "cruise travel", "adventure travel"]
            case .finance: return ["investing", "personal finance", "budgeting", "cryptocurrency", "stock market", "real estate", "retirement planning", "passive income", "financial independence", "credit cards", "tax strategies", "wealth building"]
            case .home: return ["home improvement", "gardening", "landscaping", "furniture", "power tools", "plumbing", "electrical work", "woodworking", "home renovation", "smart home", "lawn care", "composting"]
            case .entertainment: return ["movies", "TV shows", "streaming", "podcasts", "stand-up comedy", "theater", "concerts", "festivals", "book clubs", "board games", "trivia", "documentary films"]
            case .fashion: return ["fashion trends", "personal style", "makeup", "skincare", "hair care", "nail art", "sustainable fashion", "vintage clothing", "accessories", "streetwear", "luxury brands", "beauty routines"]
            case .sports: return ["basketball", "football", "soccer", "tennis", "golf", "baseball", "hockey", "volleyball", "martial arts", "boxing", "surfing", "skateboarding", "snowboarding", "fencing"]
            case .science: return ["physics", "chemistry", "biology", "astronomy", "geology", "environmental science", "neuroscience", "genetics", "quantum mechanics", "space exploration", "climate science", "oceanography"]
            case .automotive: return ["car maintenance", "auto repair", "electric vehicles", "classic cars", "motorcycles", "car detailing", "performance tuning", "road trips", "car reviews", "automotive technology"]
            case .pets: return ["dog training", "cat care", "aquarium", "bird keeping", "pet nutrition", "veterinary care", "pet photography", "animal behavior", "exotic pets", "pet grooming", "rescue animals"]
            case .music: return ["guitar", "piano", "drums", "music theory", "singing", "music production", "DJ techniques", "songwriting", "vinyl records", "concert photography", "music history", "instrument repair"]
            case .gaming: return ["video games", "esports", "game reviews", "streaming", "retro gaming", "game development", "speedrunning", "gaming PC builds", "console gaming", "indie games", "game collecting"]
            case .diy: return ["woodworking", "home crafts", "upcycling", "jewelry making", "sewing", "embroidery", "leather crafting", "soap making", "candle making", "resin art", "paper crafts", "model building"]
            case .wellness: return ["meditation", "mindfulness", "mental health", "stress relief", "sleep hygiene", "breathwork", "journaling", "aromatherapy", "sound healing", "life coaching", "self-care", "gratitude practice"]
            }
        }
    }
    
    static let adjectives = [
        "best", "new", "popular", "amazing", "creative", "unique", "modern", "simple",
        "advanced", "beginner", "professional", "innovative", "practical", "useful",
        "comprehensive", "quick", "easy", "fun", "sustainable", "effective", "top",
        "ultimate", "essential", "trending", "proven", "expert", "premium", "affordable",
        "recommended", "complete", "detailed", "step-by-step", "beginner-friendly",
        "powerful", "efficient", "time-saving", "budget", "luxury", "minimalist", "eco-friendly",
        "organic", "natural", "scientific", "evidence-based", "traditional", "contemporary",
        "classic", "cutting-edge", "revolutionary", "game-changing", "life-changing", "inspiring"
    ]
    
    static let objects = [
        "tips", "ideas", "guide", "tutorial", "examples", "techniques", "benefits",
        "methods", "basics", "secrets", "advice", "practices", "projects", "resources",
        "tools", "strategies", "fundamentals", "hacks", "tricks", "lessons", "courses",
        "workshops", "books", "videos", "podcasts", "articles", "reviews", "comparisons",
        "recommendations", "mistakes to avoid", "for beginners", "checklist", "routine",
        "setup", "equipment", "supplies", "inspiration", "trends", "statistics", "facts",
        "myths", "misconceptions", "challenges", "solutions", "case studies", "experiments",
        "research", "studies", "analysis", "breakdown", "deep dive", "overview"
    ]
    
    static let verbPhrases = [
        "how to start", "how to improve", "how to master", "how to learn", "how to get better at",
        "ways to enhance", "steps to improve", "guide to understanding", "introduction to",
        "getting started with", "improving your", "mastering the art of", "understanding",
        "exploring", "discovering", "learning about", "developing skills in", "becoming better at",
        "what you need to know about", "everything about", "the ultimate guide to", "complete beginner's guide to"
    ]
    
    static func generateQuery(enabledCategories: Set<Category>) -> String {
        guard !enabledCategories.isEmpty else {
            return "interesting facts"
        }
        
        let category = enabledCategories.randomElement()!
        let topic = category.topics.randomElement()!
        let adjective = adjectives.randomElement()!
        let object = objects.randomElement()!
        let verbPhrase = verbPhrases.randomElement()!
        
        let templates = [
            "\(adjective) \(topic) \(object)",
            "\(verbPhrase) \(topic)",
            "\(topic) for beginners",
            "\(topic) \(object) 2025",
            "best \(topic) \(object)",
            "\(adjective) \(topic) techniques",
            "why \(topic) is important",
            "benefits of \(topic)",
            "\(topic) mistakes to avoid",
            "advanced \(topic) \(object)",
            "\(adjective) ways to improve \(topic)",
            "\(topic) vs alternatives",
            "is \(topic) worth it",
            "\(topic) for professionals",
            "budget \(topic) \(object)",
            "\(topic) inspiration and \(object)",
            "common \(topic) problems",
            "\(topic) equipment and supplies",
            "latest \(topic) trends",
            "\(adjective) \(topic) routine"
        ]
        
        return templates.randomElement()!
    }
}

// MARK: - API Endpoint Categories
enum APICategory: String, CaseIterable, Identifiable, Codable {
    case wikipedia = "Wikipedia"
    case weather = "Weather"
    case news = "News & Social"
    case finance = "Finance & Crypto"
    case science = "Science & Space"
    case entertainment = "Entertainment"
    case technology = "Technology"
    case lifestyle = "Lifestyle & Culture"
    case animals = "Animals & Nature"
    case sports = "Sports"
    case food = "Food & Recipes"
    case art = "Art & Museums"
    case books = "Books & Literature"
    
    var id: String { rawValue }
}

enum APILanguage: String, CaseIterable, Identifiable, Codable {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case japanese = "Japanese"
    case chinese = "Chinese"
    case portuguese = "Portuguese"
    case italian = "Italian"
    case russian = "Russian"
    case arabic = "Arabic"
    case korean = "Korean"
    case hindi = "Hindi"
    
    var id: String { rawValue }
    
    var wikipediaCode: String {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .japanese: return "ja"
        case .chinese: return "zh"
        case .portuguese: return "pt"
        case .italian: return "it"
        case .russian: return "ru"
        case .arabic: return "ar"
        case .korean: return "ko"
        case .hindi: return "hi"
        }
    }
}

struct APIEndpoint {
    let url: String
    let category: APICategory
    let language: APILanguage?
    let description: String
}

// MARK: - Schedule
struct DaySchedule: Codable, Identifiable {
    let id: UUID
    var dayOfWeek: Int
    var isEnabled: Bool
    var startHour: Int
    var endHour: Int
    
    init(id: UUID = UUID(), dayOfWeek: Int, isEnabled: Bool, startHour: Int, endHour: Int) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.isEnabled = isEnabled
        self.startHour = startHour
        self.endHour = endHour
    }
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let calendar = Calendar.current
        let weekday = calendar.date(from: DateComponents(weekday: dayOfWeek))!
        return formatter.string(from: weekday)
    }
}

// MARK: - Statistics
struct SearchStats: Codable {
    var totalSearches: Int = 0
    var todaySearches: Int = 0
    var lastResetDate: Date = Date()
    var weeklySearches: [Int] = Array(repeating: 0, count: 7)
    var searchHistory: [SearchRecord] = []
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var totalDataUsed: Int64 = 0
    
    var successRate: Double {
        let total = successfulRequests + failedRequests
        guard total > 0 else { return 0 }
        return Double(successfulRequests) / Double(total) * 100
    }
    
    struct SearchRecord: Codable, Identifiable {
        let id: UUID
        let query: String
        let timestamp: Date
        let mode: String
        let success: Bool
        let dataSize: Int64?
        let apiURL: String?
        let apiCategory: String?
        let apiLanguage: String?
        
        init(id: UUID = UUID(), query: String, timestamp: Date, mode: String, success: Bool, dataSize: Int64? = nil, apiURL: String? = nil, apiCategory: String? = nil, apiLanguage: String? = nil) {
            self.id = id
            self.query = query
            self.timestamp = timestamp
            self.mode = mode
            self.success = success
            self.dataSize = dataSize
            self.apiURL = apiURL
            self.apiCategory = apiCategory
            self.apiLanguage = apiLanguage
        }
    }
    
    mutating func addSearch(query: String, mode: String, success: Bool = true, dataSize: Int64 = 0, apiURL: String? = nil, apiCategory: String? = nil, apiLanguage: String? = nil) -> Bool {
        totalSearches += 1
        
        if success {
            successfulRequests += 1
        } else {
            failedRequests += 1
        }
        
        totalDataUsed += dataSize
        
        let today = Calendar.current.startOfDay(for: Date())
        var wasReset = false
        if Calendar.current.startOfDay(for: lastResetDate) < today {
            todaySearches = 0
            lastResetDate = Date()
            weeklySearches.removeFirst()
            weeklySearches.append(0)
            wasReset = true
        }
        
        todaySearches += 1
        weeklySearches[weeklySearches.count - 1] += 1
        
        let record = SearchRecord(
            query: query,
            timestamp: Date(),
            mode: mode,
            success: success,
            dataSize: dataSize > 0 ? dataSize : nil,
            apiURL: apiURL,
            apiCategory: apiCategory,
            apiLanguage: apiLanguage
        )
        searchHistory.insert(record, at: 0)
        if searchHistory.count > 100 {
            searchHistory.removeLast()
        }
        
        return wasReset
    }
    
    mutating func addManualSearch(query: String) {
        totalSearches += 1
        
        let today = Calendar.current.startOfDay(for: Date())
        if Calendar.current.startOfDay(for: lastResetDate) < today {
            lastResetDate = Date()
            weeklySearches.removeFirst()
            weeklySearches.append(0)
        }
        
        weeklySearches[weeklySearches.count - 1] += 1
        
        let record = SearchRecord(
            query: query,
            timestamp: Date(),
            mode: "Safari Search",
            success: true
        )
        searchHistory.insert(record, at: 0)
        if searchHistory.count > 100 {
            searchHistory.removeLast()
        }
    }
    
    mutating func checkAndResetDaily() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        if Calendar.current.startOfDay(for: lastResetDate) < today {
            todaySearches = 0
            lastResetDate = Date()
            weeklySearches.removeFirst()
            weeklySearches.append(0)
            return true
        }
        return false
    }
    
    func formattedDataUsage() -> String {
        let bytes = Double(totalDataUsed)
        if bytes < 1024 {
            return String(format: "%.0f B", bytes)
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", bytes / (1024 * 1024 * 1024))
        }
    }
    
    func estimatedBatteryImpact() -> String {
        let requestsPerDay = Double(totalSearches) / max(1, Double(Calendar.current.dateComponents([.day], from: lastResetDate, to: Date()).day ?? 1))
        let dailyImpact = requestsPerDay * 0.0003
        
        if dailyImpact < 0.001 {
            return "<0.001%"
        } else if dailyImpact < 0.01 {
            return String(format: "~%.3f%%", dailyImpact)
        } else {
            return String(format: "~%.2f%%", dailyImpact)
        }
    }
}
