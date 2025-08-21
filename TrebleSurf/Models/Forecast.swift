//
//  Forecast.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 12/05/2025.
//

import Foundation

// Original API response structures
struct ForecastResponse: Codable, Identifiable {
    let data: ForecastData
    let forecast_timestamp: String
    let generated_at: String
    let spot_id: String
    
    var id: String {
        "\(spot_id)-\(forecast_timestamp)"
    }
}

struct ForecastData: Codable {
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

// Flattened structure for storage and easier usage
struct ForecastEntry: Codable, Identifiable, Equatable {
    let id: String
    let spotId: String
    let forecastTimestamp: Date
    let generatedAt: Date
    let dateForecastedFor: Date
    
    // Forecast data
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
    
    // Create from API response
    init(from response: ForecastResponse) {
        let dateFormatter = ISO8601DateFormatter()
        
        self.spotId = response.spot_id
        self.forecastTimestamp = dateFormatter.date(from: response.forecast_timestamp) ?? Date()
        self.generatedAt = dateFormatter.date(from: response.generated_at) ?? Date()
        // Create a specific formatter for dateForecastedFor
            let dateFormatted = DateFormatter()
            dateFormatted.dateFormat = "yyyy-MM-dd HH:mm:ss"
            self.dateForecastedFor = dateFormatted.date(from: response.data.dateForecastedFor) ?? Date()
        // Generate ID from spot and time
        self.id = "\(spotId)-\(forecastTimestamp.timeIntervalSince1970)"
        
        // Copy all forecast data fields
        self.directionQuality = response.data.directionQuality
        self.humidity = response.data.humidity
        self.precipitation = response.data.precipitation
        self.pressure = response.data.pressure
        self.relativeWindDirection = response.data.relativeWindDirection
        self.surfMessiness = response.data.surfMessiness
        self.surfSize = response.data.surfSize
        self.swellDirection = response.data.swellDirection
        self.swellHeight = response.data.swellHeight
        self.swellPeriod = response.data.swellPeriod
        self.temperature = response.data.temperature
        self.waterTemperature = response.data.waterTemperature
        self.waveEnergy = response.data.waveEnergy
        self.windDirection = response.data.windDirection
        self.windSpeed = response.data.windSpeed
    }
    
    // Convert back to ForecastResponse if needed
    func toForecastResponse() -> ForecastResponse {
        let dateFormatter = ISO8601DateFormatter()
        
        let forecastData = ForecastData(from: [
            "dateForecastedFor": dateFormatter.string(from: dateForecastedFor),
            "directionQuality": directionQuality,
            "humidity": humidity,
            "precipitation": precipitation,
            "pressure": pressure,
            "relativeWindDirection": relativeWindDirection,
            "surfMessiness": surfMessiness,
            "surfSize": surfSize,
            "swellDirection": swellDirection,
            "swellHeight": swellHeight,
            "swellPeriod": swellPeriod,
            "temperature": temperature,
            "waterTemperature": waterTemperature,
            "waveEnergy": waveEnergy,
            "windDirection": windDirection,
            "windSpeed": windSpeed
        ])
        
        return ForecastResponse(
            data: forecastData,
            forecast_timestamp: dateFormatter.string(from: forecastTimestamp),
            generated_at: dateFormatter.string(from: generatedAt),
            spot_id: spotId
        )
    }
}

// Helper extension to convert between formats
extension Array where Element == ForecastResponse {
    func toForecastEntries() -> [ForecastEntry] {
        self.map { ForecastEntry(from: $0) }
    }
}

extension Array where Element == ForecastEntry {
    func toForecastResponses() -> [ForecastResponse] {
        self.map { $0.toForecastResponse() }
    }
}
