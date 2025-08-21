//
//  CurrentConditions.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 11/05/2025.
//

// Enum for relative wind direction types
enum RelativeWindDirection: String, CaseIterable {
    case offshore = "Offshore"
    case onshore = "Onshore"
    case crossshore = "Crossshore"
    case crossOnshore = "Cross-Onshore"
    case crossOffshore = "Cross-Offshore"
    
    // Display value that removes 'shore' from Cross-Onshore and Cross-Offshore
    var displayValue: String {
        switch self {
        case .crossOnshore:
            return "Cross-On"
        case .crossOffshore:
            return "Cross-Off"
        default:
            return self.rawValue
        }
    }
    
    // Initialize from string with fallback
    init(from string: String) {
        if let direction = RelativeWindDirection.allCases.first(where: { $0.rawValue == string }) {
            self = direction
        } else {
            // If no match found, we'll handle this in the displayValue
            // For now, just store the original string
            self = .crossshore // This won't be used when we have a custom string
        }
    }
}

struct CurrentConditionsResponse: Codable {
    let data: ConditionData
    let forecast_timestamp: String
    let generated_at: String
    let spot_id: String
}

struct ConditionData: Codable {
    let dateForecastedFor: String
    let directionQuality: Double
    let humidity: Double
    let precipitation: Double
    let pressure: Double
    let relativeWindDirection: String
    let surfMessiness: String
    let surfSize: Double
    let swellDirection: Double
    let swellHeight: Double
    let swellPeriod: Double
    let temperature: Double
    let waterTemperature: Double
    let waveEnergy: Double
    let windDirection: Double
    let windSpeed: Double
    
    // Computed property for formatted relative wind direction
    var formattedRelativeWindDirection: String {
        // Check if it matches our specific Cross-Onshore/Cross-Offshore cases
        if relativeWindDirection == "Cross-Onshore" {
            return "Cross-On"
        } else if relativeWindDirection == "Cross-Offshore" {
            return "Cross-Off"
        } else {
            // For all other cases, return the original value
            return relativeWindDirection
        }
    }

    // Custom initializer
    init(from data: [String: Any]) {
        self.dateForecastedFor = data["dateForecastedFor"] as? String ?? ""
        self.directionQuality = data["directionQuality"] as? Double ?? 0.0
        self.humidity = data["humidity"] as? Double ?? 0.0
        self.precipitation = data["precipitation"] as? Double ?? 0.0
        self.pressure = data["pressure"] as? Double ?? 0.0
        self.relativeWindDirection = data["relativeWindDirection"] as? String ?? ""
        self.surfMessiness = data["surfMessiness"] as? String ?? ""
        self.surfSize = data["surfSize"] as? Double ?? 0.0
        self.swellDirection = data["swellDirection"] as? Double ?? 0.0
        self.swellHeight = data["swellHeight"] as? Double ?? 0.0
        self.swellPeriod = data["swellPeriod"] as? Double ?? 0.0
        self.temperature = data["temperature"] as? Double ?? 0.0
        self.waterTemperature = data["waterTemperature"] as? Double ?? 0.0
        self.waveEnergy = data["waveEnergy"] as? Double ?? 0.0
        self.windDirection = data["windDirection"] as? Double ?? 0.0
        self.windSpeed = data["windSpeed"] as? Double ?? 0.0
    }
}
