//
//  Models.swift
//  DigiNoise
//
//  Simplified data models - removed stats tracking
//

import Foundation

// MARK: - Search Generator
struct SearchGenerator {
    enum Category: String, CaseIterable {
        case cooking = "Cooking"
        case fitness = "Fitness"
        case tech = "Technology"
        case lifestyle = "Lifestyle"
        case travel = "Travel"
        case science = "Science"
        case entertainment = "Entertainment"
        case sports = "Sports"
        
        var topics: [String] {
            switch self {
            case .cooking: return ["recipe", "cooking", "nutrition", "meal prep"]
            case .fitness: return ["fitness", "yoga", "running", "health"]
            case .tech: return ["technology", "AI", "apps", "software"]
            case .lifestyle: return ["fashion", "home", "minimalism", "productivity"]
            case .travel: return ["travel", "destinations", "culture", "food"]
            case .science: return ["science", "space", "nature", "research"]
            case .entertainment: return ["movies", "music", "books", "games"]
            case .sports: return ["sports", "basketball", "soccer", "tennis"]
            }
        }
    }
    
    static let adjectives = ["best", "new", "popular", "amazing", "creative", "simple", "easy"]
    static let objects = ["tips", "guide", "ideas", "benefits", "tutorial"]
    
    static func generate(enabledCategories: Set<Category>? = nil) -> String {
        let categories = enabledCategories ?? Set(Category.allCases)
        guard let category = categories.randomElement() else {
            return "interesting facts"
        }
        
        let topic = category.topics.randomElement()!
        let adjective = adjectives.randomElement()!
        let object = objects.randomElement()!
        
        let templates = [
            "\(adjective) \(topic) \(object)",
            "\(topic) \(object)",
            "how to \(topic)",
            "best \(topic) \(object)"
        ]
        
        return templates.randomElement()!
    }
}

// MARK: - API Endpoints
enum APICategory: String, CaseIterable {
    case wikipedia = "Wikipedia"
    case weather = "Weather"
    case news = "News"
    case tech = "Technology"
    case entertainment = "Entertainment"
}

enum APILanguage: String, CaseIterable {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    
    var code: String {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        }
    }
}

struct APIEndpoint {
    let url: String
    let category: APICategory
    let description: String
}

// MARK: - Simple Stats (Minimal)
struct SimpleStats: Codable {
    var totalRequests: Int = 0
    var lastRequestDate: Date?
    
    mutating func recordRequest() {
        totalRequests += 1
        lastRequestDate = Date()
    }
}
