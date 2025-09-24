//
//  AIPredictedForecast.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 01/01/2025.
//

import Foundation

// MARK: - DynamoDB Attribute Value Types

enum DynamoDBAttributeType: String, Codable {
    case string = "S"
    case number = "N"
    case boolean = "BOOL"
    case binary = "B"
    case stringSet = "SS"
    case numberSet = "NS"
    case binarySet = "BS"
    case list = "L"
    case map = "M"
    case null = "NULL"
}

struct DynamoDBAttributeValue: Codable {
    let stringValue: String?
    let numberValue: String?
    let booleanValue: Bool?
    let binaryValue: Data?
    let stringSetValue: [String]?
    let numberSetValue: [String]?
    let binarySetValue: [Data]?
    let listValue: [DynamoDBAttributeValue]?
    let mapValue: [String: DynamoDBAttributeValue]?
    let nullValue: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case stringValue = "S"
        case numberValue = "N"
        case booleanValue = "BOOL"
        case binaryValue = "B"
        case stringSetValue = "SS"
        case numberSetValue = "NS"
        case binarySetValue = "BS"
        case listValue = "L"
        case mapValue = "M"
        case nullValue = "NULL"
    }
    
    // Helper computed properties for easier access
    var string: String? {
        return stringValue
    }
    
    var number: Double? {
        guard let numberValue = numberValue else { return nil }
        return Double(numberValue)
    }
    
    var integer: Int? {
        guard let numberValue = numberValue else { return nil }
        return Int(numberValue)
    }
    
    var boolean: Bool? {
        return booleanValue
    }
}

// MARK: - AI Predicted Forecast Response

struct AIPredictedForecastResponse: Codable, Identifiable {
    let arrival_time: DynamoDBAttributeValue
    let direction_quality: DynamoDBAttributeValue
    let distance_km: DynamoDBAttributeValue
    let spot_id: DynamoDBAttributeValue
    let predicted_height: DynamoDBAttributeValue
    let surf_size: DynamoDBAttributeValue
    let travel_time_hours: DynamoDBAttributeValue
    let confidence: DynamoDBAttributeValue
    let predicted_direction: DynamoDBAttributeValue
    let calibration_applied: DynamoDBAttributeValue
    let hours_ahead: DynamoDBAttributeValue
    let calibration_confidence: DynamoDBAttributeValue
    let predicted_period: DynamoDBAttributeValue
    
    var id: String {
        return spot_id.string ?? UUID().uuidString
    }
    
    // Computed properties for easier access
    var spotId: String {
        return spot_id.string ?? ""
    }
    
    var arrivalTime: Date {
        guard let timeString = arrival_time.string else { return Date() }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: timeString) ?? Date()
    }
    
    var directionQuality: Double {
        return direction_quality.number ?? 0.0
    }
    
    var distanceKm: Double {
        return distance_km.number ?? 0.0
    }
    
    var predictedHeight: Double {
        return predicted_height.number ?? 0.0
    }
    
    var surfSize: Double {
        return surf_size.number ?? 0.0
    }
    
    var travelTimeHours: Double {
        return travel_time_hours.number ?? 0.0
    }
    
    var confidenceValue: Double {
        return confidence.number ?? 0.0
    }
    
    var predictedDirection: Double {
        return predicted_direction.number ?? 0.0
    }
    
    var calibrationApplied: Bool {
        return calibration_applied.number == 1.0
    }
    
    var hoursAhead: Double {
        return hours_ahead.number ?? 0.0
    }
    
    var calibrationConfidence: Double {
        return calibration_confidence.number ?? 0.0
    }
    
    var predictedPeriod: Double {
        return predicted_period.number ?? 0.0
    }
}

// MARK: - Flattened AI Predicted Forecast Entry

struct AIPredictedForecastEntry: Codable, Identifiable, Equatable {
    let id: String
    let spotId: String
    let arrivalTime: Date
    let directionQuality: Double
    let distanceKm: Double
    let predictedHeight: Double
    let surfSize: Double
    let travelTimeHours: Double
    let confidence: Double
    let predictedDirection: Double
    let calibrationApplied: Bool
    let hoursAhead: Double
    let calibrationConfidence: Double
    let predictedPeriod: Double
    
    // Create from API response
    init(from response: AIPredictedForecastResponse) {
        self.spotId = response.spotId
        self.arrivalTime = response.arrivalTime
        self.directionQuality = response.directionQuality
        self.distanceKm = response.distanceKm
        self.predictedHeight = response.predictedHeight
        self.surfSize = response.surfSize
        self.travelTimeHours = response.travelTimeHours
        self.confidence = response.confidenceValue
        self.predictedDirection = response.predictedDirection
        self.calibrationApplied = response.calibrationApplied
        self.hoursAhead = response.hoursAhead
        self.calibrationConfidence = response.calibrationConfidence
        self.predictedPeriod = response.predictedPeriod
        
        // Generate ID from spot and arrival time
        self.id = "\(spotId)-\(arrivalTime.timeIntervalSince1970)"
    }
    
    // Convert back to AIPredictedForecastResponse if needed
    func toAIPredictedForecastResponse() -> AIPredictedForecastResponse {
        let dateFormatter = ISO8601DateFormatter()
        
        return AIPredictedForecastResponse(
            arrival_time: DynamoDBAttributeValue(stringValue: dateFormatter.string(from: arrivalTime), numberValue: nil, booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            direction_quality: DynamoDBAttributeValue(stringValue: nil, numberValue: String(directionQuality), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            distance_km: DynamoDBAttributeValue(stringValue: nil, numberValue: String(distanceKm), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            spot_id: DynamoDBAttributeValue(stringValue: spotId, numberValue: nil, booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            predicted_height: DynamoDBAttributeValue(stringValue: nil, numberValue: String(predictedHeight), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            surf_size: DynamoDBAttributeValue(stringValue: nil, numberValue: String(surfSize), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            travel_time_hours: DynamoDBAttributeValue(stringValue: nil, numberValue: String(travelTimeHours), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            confidence: DynamoDBAttributeValue(stringValue: nil, numberValue: String(confidence), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            predicted_direction: DynamoDBAttributeValue(stringValue: nil, numberValue: String(predictedDirection), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            calibration_applied: DynamoDBAttributeValue(stringValue: nil, numberValue: String(calibrationApplied ? 1 : 0), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            hours_ahead: DynamoDBAttributeValue(stringValue: nil, numberValue: String(hoursAhead), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            calibration_confidence: DynamoDBAttributeValue(stringValue: nil, numberValue: String(calibrationConfidence), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            predicted_period: DynamoDBAttributeValue(stringValue: nil, numberValue: String(predictedPeriod), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil)
        )
    }
}

// MARK: - Helper Extensions

extension Array where Element == AIPredictedForecastResponse {
    func toAIPredictedForecastEntries() -> [AIPredictedForecastEntry] {
        self.map { AIPredictedForecastEntry(from: $0) }
    }
}

extension Array where Element == AIPredictedForecastEntry {
    func toAIPredictedForecastResponses() -> [AIPredictedForecastResponse] {
        self.map { $0.toAIPredictedForecastResponse() }
    }
}

// MARK: - AI Predicted Forecast Quality Assessment

extension AIPredictedForecastEntry {
    /// Returns a quality assessment based on confidence and direction quality
    var qualityAssessment: AIPredictionQuality {
        let overallQuality = (confidence + directionQuality) / 2
        
        switch overallQuality {
        case 0.8...1.0:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.4..<0.6:
            return .fair
        default:
            return .poor
        }
    }
    
    /// Returns a surf condition assessment based on surf size and confidence
    var surfConditionAssessment: SurfCondition {
        switch surfSize {
        case 0..<1.0:
            return .flat
        case 1.0..<2.0:
            return .small
        case 2.0..<3.0:
            return .fair
        case 3.0..<4.0:
            return .good
        case 4.0..<6.0:
            return .veryGood
        default:
            return .epic
        }
    }
    
    /// Returns a formatted confidence percentage
    var confidencePercentage: String {
        return "\(Int(confidence * 100))%"
    }
    
    /// Returns a formatted direction quality percentage
    var directionQualityPercentage: String {
        return "\(Int(directionQuality * 100))%"
    }
    
    /// Returns arrival time formatted for display
    var formattedArrivalTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: arrivalTime)
    }
    
    /// Returns travel time formatted for display
    var formattedTravelTime: String {
        if travelTimeHours < 1.0 {
            let minutes = Int(travelTimeHours * 60)
            return "\(minutes) min"
        } else {
            return String(format: "%.1f hrs", travelTimeHours)
        }
    }
    
    /// Returns hours ahead formatted for display
    var formattedHoursAhead: String {
        if hoursAhead < 1.0 {
            let minutes = Int(hoursAhead * 60)
            return "\(minutes) min"
        } else {
            return String(format: "%.1f hrs", hoursAhead)
        }
    }
    
    /// Returns a formatted calibration confidence percentage
    var calibrationConfidencePercentage: String {
        return "\(Int(calibrationConfidence * 100))%"
    }
}

// MARK: - Quality Enums

enum AIPredictionQuality: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "checkmark.circle.fill"
        case .fair: return "exclamationmark.triangle.fill"
        case .poor: return "xmark.circle.fill"
        }
    }
}
