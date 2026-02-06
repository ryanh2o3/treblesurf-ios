//
//  SwellPrediction.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 01/01/2025.
//

import Foundation

// MARK: - Swell Prediction Response Models

struct SwellPredictionResponse: Codable, Identifiable {
    let spot_id: String
    let forecast_timestamp: String
    let generated_at: String
    let predicted_height: Double
    let predicted_period: Double
    let predicted_direction: Double
    let surf_size: Double
    let travel_time_hours: Double
    let arrival_time: String
    let direction_quality: Double
    let calibration_applied: Bool
    let calibration_confidence: Double
    let calibration_factor: CalibrationFactor?
    let confidence: Double
    let distance_km: Double
    let reports_analyzed: Int?
    let hours_ahead: Double?
    
    var id: String {
        "\(spot_id)-\(forecast_timestamp)"
    }
    
    // Public initializer for creating instances programmatically
    init(spot_id: String, forecast_timestamp: String, generated_at: String, predicted_height: Double, predicted_period: Double, predicted_direction: Double, surf_size: Double, travel_time_hours: Double, arrival_time: String, direction_quality: Double, calibration_applied: Bool, calibration_confidence: Double, calibration_factor: CalibrationFactor?, confidence: Double, distance_km: Double, reports_analyzed: Int?, hours_ahead: Double? = nil) {
        self.spot_id = spot_id
        self.forecast_timestamp = forecast_timestamp
        self.generated_at = generated_at
        self.predicted_height = predicted_height
        self.predicted_period = predicted_period
        self.predicted_direction = predicted_direction
        self.surf_size = surf_size
        self.travel_time_hours = travel_time_hours
        self.arrival_time = arrival_time
        self.direction_quality = direction_quality
        self.calibration_applied = calibration_applied
        self.calibration_confidence = calibration_confidence
        self.calibration_factor = calibration_factor
        self.confidence = confidence
        self.distance_km = distance_km
        self.reports_analyzed = reports_analyzed
        self.hours_ahead = hours_ahead
    }
    
    // Initializer for DynamoDB format data
    init(from dynamoDBData: [String: DynamoDBAttributeValue]) {
        self.spot_id = dynamoDBData["spot_id"]?.string ?? ""
        // Use current time for forecast_timestamp and generated_at if not provided
        let currentTime = ISO8601DateFormatter().string(from: Date())
        self.forecast_timestamp = dynamoDBData["forecast_timestamp"]?.string ?? currentTime
        self.generated_at = dynamoDBData["generated_at"]?.string ?? currentTime
        self.predicted_height = dynamoDBData["predicted_height"]?.number ?? 0.0
        self.predicted_period = dynamoDBData["predicted_period"]?.number ?? 0.0
        self.predicted_direction = dynamoDBData["predicted_direction"]?.number ?? 0.0
        self.surf_size = dynamoDBData["surf_size"]?.number ?? 0.0
        self.travel_time_hours = dynamoDBData["travel_time_hours"]?.number ?? 0.0
        self.arrival_time = dynamoDBData["arrival_time"]?.string ?? ""
        self.direction_quality = dynamoDBData["direction_quality"]?.number ?? 0.0
        self.calibration_applied = dynamoDBData["calibration_applied"]?.number == 1.0
        self.calibration_confidence = dynamoDBData["calibration_confidence"]?.number ?? 0.0
        self.calibration_factor = nil // Not in DynamoDB format
        self.confidence = dynamoDBData["confidence"]?.number ?? 0.0
        self.distance_km = dynamoDBData["distance_km"]?.number ?? 0.0
        self.reports_analyzed = nil // Not in DynamoDB format
        self.hours_ahead = dynamoDBData["hours_ahead"]?.number ?? 0.0
    }
    
    // Custom decoding to handle arrival_time as either String or numeric timestamp
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        spot_id = try container.decode(String.self, forKey: .spot_id)
        forecast_timestamp = try container.decode(String.self, forKey: .forecast_timestamp)
        generated_at = try container.decode(String.self, forKey: .generated_at)
        predicted_height = try container.decode(Double.self, forKey: .predicted_height)
        predicted_period = try container.decode(Double.self, forKey: .predicted_period)
        predicted_direction = try container.decode(Double.self, forKey: .predicted_direction)
        surf_size = try container.decode(Double.self, forKey: .surf_size)
        travel_time_hours = try container.decode(Double.self, forKey: .travel_time_hours)
        direction_quality = try container.decode(Double.self, forKey: .direction_quality)
        
        // Handle calibration_applied as either Bool or numeric (0/1)
        if let calibrationAppliedBool = try? container.decode(Bool.self, forKey: .calibration_applied) {
            calibration_applied = calibrationAppliedBool
        } else if let calibrationAppliedNumber = try? container.decode(Int.self, forKey: .calibration_applied) {
            calibration_applied = calibrationAppliedNumber != 0
        } else {
            calibration_applied = false
        }
        
        calibration_confidence = try container.decode(Double.self, forKey: .calibration_confidence)
        calibration_factor = try container.decodeIfPresent(CalibrationFactor.self, forKey: .calibration_factor)
        confidence = try container.decode(Double.self, forKey: .confidence)
        distance_km = try container.decode(Double.self, forKey: .distance_km)
        reports_analyzed = try container.decodeIfPresent(Int.self, forKey: .reports_analyzed)
        hours_ahead = try container.decodeIfPresent(Double.self, forKey: .hours_ahead)
        
        // Handle arrival_time as either String or numeric timestamp
        if let arrivalTimeString = try? container.decode(String.self, forKey: .arrival_time) {
            arrival_time = arrivalTimeString
        } else if let arrivalTimeNumber = try? container.decode(Double.self, forKey: .arrival_time) {
            // Convert numeric timestamp to ISO8601 string
            let date = Date(timeIntervalSince1970: arrivalTimeNumber)
            let formatter = ISO8601DateFormatter()
            arrival_time = formatter.string(from: date)
        } else {
            // Fallback to current time if neither works
            let formatter = ISO8601DateFormatter()
            arrival_time = formatter.string(from: Date())
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case spot_id, forecast_timestamp, generated_at, predicted_height
        case predicted_period, predicted_direction, surf_size, travel_time_hours
        case arrival_time, direction_quality, calibration_applied, calibration_confidence, calibration_factor
        case confidence, distance_km, reports_analyzed, hours_ahead
    }
}

struct CalibrationFactor: Codable, Equatable {
    let height_factor: Double
    let surf_size_factor: Double
    let confidence_boost: Double
    let method: String
    let similar_reports_count: Int?
    let avg_reported_surf_size: Double?
}

struct SwellPredictionStatusResponse: Codable {
    let total_predictions: Int
    let last_updated: String
    let status: String
    let message: String
}

// MARK: - Flattened Swell Prediction Entry

struct SwellPredictionEntry: Codable, Identifiable, Equatable {
    let id: String
    let spotId: String
    let forecastTimestamp: Date
    let generatedAt: Date
    let predictedHeight: Double
    let predictedPeriod: Double
    let predictedDirection: Double
    let surfSize: Double
    let travelTimeHours: Double
    let arrivalTime: Date
    let directionQuality: Double
    let calibrationApplied: Bool
    let calibrationConfidence: Double
    let calibrationFactor: CalibrationFactor?
    let confidence: Double
    let distanceKm: Double
    let reportsAnalyzed: Int
    let hoursAhead: Double
    
    // Create from API response
    init(from response: SwellPredictionResponse) {
        // Use DateFormatter for parsing dates without timezone info
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        // For timestamps with milliseconds
        let dateFormatterWithMs = DateFormatter()
        dateFormatterWithMs.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        dateFormatterWithMs.timeZone = TimeZone(abbreviation: "UTC")
        
        self.spotId = response.spot_id
        
        // Parse forecast timestamp (numeric)
        if let timestamp = Double(response.forecast_timestamp) {
            self.forecastTimestamp = Date(timeIntervalSince1970: timestamp)
        } else {
            self.forecastTimestamp = Date()
        }
        
        // Parse generated at timestamp (numeric)
        if let timestamp = Double(response.generated_at) {
            self.generatedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            self.generatedAt = Date()
        }
        
        // Parse arrival time (string with or without milliseconds)
        if let date = dateFormatterWithMs.date(from: response.arrival_time) {
            self.arrivalTime = date
        } else if let date = dateFormatter.date(from: response.arrival_time) {
            self.arrivalTime = date
        } else {
            self.arrivalTime = Date()
        }
        
        // Generate ID from spot and arrival time to ensure uniqueness
        self.id = "\(spotId)-\(arrivalTime.timeIntervalSince1970)"
        
        // Copy all prediction data fields
        self.predictedHeight = response.predicted_height
        self.predictedPeriod = response.predicted_period
        self.predictedDirection = response.predicted_direction
        self.surfSize = response.surf_size
        self.travelTimeHours = response.travel_time_hours
        self.directionQuality = response.direction_quality
        self.calibrationApplied = response.calibration_applied
        self.calibrationConfidence = response.calibration_confidence
        self.calibrationFactor = response.calibration_factor
        self.confidence = response.confidence
        self.distanceKm = response.distance_km
        self.reportsAnalyzed = response.reports_analyzed ?? 0
        self.hoursAhead = response.hours_ahead ?? 0.0
    }
    
    // Convert back to SwellPredictionResponse if needed
    func toSwellPredictionResponse() -> SwellPredictionResponse {
        let dateFormatter = ISO8601DateFormatter()
        
        return SwellPredictionResponse(
            spot_id: spotId,
            forecast_timestamp: dateFormatter.string(from: forecastTimestamp),
            generated_at: dateFormatter.string(from: generatedAt),
            predicted_height: predictedHeight,
            predicted_period: predictedPeriod,
            predicted_direction: predictedDirection,
            surf_size: surfSize,
            travel_time_hours: travelTimeHours,
            arrival_time: dateFormatter.string(from: arrivalTime),
            direction_quality: directionQuality,
            calibration_applied: calibrationApplied,
            calibration_confidence: calibrationConfidence,
            calibration_factor: calibrationFactor,
            confidence: confidence,
            distance_km: distanceKm,
            reports_analyzed: reportsAnalyzed,
            hours_ahead: hoursAhead
        )
    }
}

// MARK: - Helper Extensions

extension Array where Element == SwellPredictionResponse {
    func toSwellPredictionEntries() -> [SwellPredictionEntry] {
        self.map { SwellPredictionEntry(from: $0) }
    }
}

extension Array where Element == SwellPredictionEntry {
    func toSwellPredictionResponses() -> [SwellPredictionResponse] {
        self.map { $0.toSwellPredictionResponse() }
    }
}

// MARK: - Swell Prediction Quality Assessment

extension SwellPredictionEntry {
    /// Returns a quality assessment based on confidence and direction quality
    var qualityAssessment: SwellPredictionQuality {
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
        formatter.timeZone = TimeZone(abbreviation: "UTC")
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
}

// MARK: - Quality Enums

enum SwellPredictionQuality: String, CaseIterable {
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

enum SurfCondition: String, CaseIterable {
    case flat = "Flat"
    case small = "Small"
    case fair = "Fair"
    case good = "Good"
    case veryGood = "Very Good"
    case epic = "Epic"
    
    var color: String {
        switch self {
        case .flat: return "gray"
        case .small: return "blue"
        case .fair: return "green"
        case .good: return "orange"
        case .veryGood: return "red"
        case .epic: return "purple"
        }
    }
    
    var icon: String {
        switch self {
        case .flat: return "minus"
        case .small: return "wave.3.right"
        case .fair: return "wave.3.right.fill"
        case .good: return "wave.3.right.fill"
        case .veryGood: return "wave.3.right.fill"
        case .epic: return "wave.3.right.fill"
        }
    }
}
