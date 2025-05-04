//
//  CurrentConditions.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 11/05/2025.
//

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
