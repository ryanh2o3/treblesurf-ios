//
//  AIPredictedForecastTest.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 01/01/2025.
//

import Foundation

// MARK: - Test Data and Validation

struct AIPredictedForecastTest {
    
    /// Test data matching the provided DynamoDB format
    static let testDynamoDBData: [String: DynamoDBAttributeValue] = [
        "arrival_time": DynamoDBAttributeValue(
            stringValue: "2025-09-25T00:04:51.259659",
            numberValue: nil,
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "direction_quality": DynamoDBAttributeValue(
            stringValue: nil,
            numberValue: "0",
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "distance_km": DynamoDBAttributeValue(
            stringValue: nil,
            numberValue: "98.907205",
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "spot_id": DynamoDBAttributeValue(
            stringValue: "Ireland#Donegal#Ballyhiernan",
            numberValue: nil,
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "predicted_height": DynamoDBAttributeValue(
            stringValue: nil,
            numberValue: "0.675314",
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "surf_size": DynamoDBAttributeValue(
            stringValue: nil,
            numberValue: "0.616263",
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "travel_time_hours": DynamoDBAttributeValue(
            stringValue: nil,
            numberValue: "6.069675",
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "confidence": DynamoDBAttributeValue(
            stringValue: nil,
            numberValue: "1",
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "predicted_direction": DynamoDBAttributeValue(
            stringValue: nil,
            numberValue: "-125.310694",
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "calibration_applied": DynamoDBAttributeValue(
            stringValue: nil,
            numberValue: "0",
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "hours_ahead": DynamoDBAttributeValue(
            stringValue: nil,
            numberValue: "0",
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "calibration_confidence": DynamoDBAttributeValue(
            stringValue: nil,
            numberValue: "1",
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        ),
        "predicted_period": DynamoDBAttributeValue(
            stringValue: nil,
            numberValue: "5.5456",
            booleanValue: nil,
            binaryValue: nil,
            stringSetValue: nil,
            numberSetValue: nil,
            binarySetValue: nil,
            listValue: nil,
            mapValue: nil,
            nullValue: nil
        )
    ]
    
    /// Test the parsing of DynamoDB data
    static func testDynamoDBParsing() {
        // Test AIPredictedForecastResponse
        let aiResponse = AIPredictedForecastResponse(
            arrival_time: testDynamoDBData["arrival_time"]!,
            direction_quality: testDynamoDBData["direction_quality"]!,
            distance_km: testDynamoDBData["distance_km"]!,
            spot_id: testDynamoDBData["spot_id"]!,
            predicted_height: testDynamoDBData["predicted_height"]!,
            surf_size: testDynamoDBData["surf_size"]!,
            travel_time_hours: testDynamoDBData["travel_time_hours"]!,
            confidence: testDynamoDBData["confidence"]!,
            predicted_direction: testDynamoDBData["predicted_direction"]!,
            calibration_applied: testDynamoDBData["calibration_applied"]!,
            hours_ahead: testDynamoDBData["hours_ahead"]!,
            calibration_confidence: testDynamoDBData["calibration_confidence"]!,
            predicted_period: testDynamoDBData["predicted_period"]!
        )

        // Test AIPredictedForecastEntry
        let _ = AIPredictedForecastEntry(from: aiResponse)

        // Test SwellPredictionResponse with DynamoDB data
        let swellResponse = SwellPredictionResponse(from: testDynamoDBData)

        // Test SwellPredictionEntry
        let _ = SwellPredictionEntry(from: swellResponse)
    }
    
    /// Test the conversion back to DynamoDB format
    static func testDynamoDBConversion() {
        let aiResponse = AIPredictedForecastResponse(
            arrival_time: testDynamoDBData["arrival_time"]!,
            direction_quality: testDynamoDBData["direction_quality"]!,
            distance_km: testDynamoDBData["distance_km"]!,
            spot_id: testDynamoDBData["spot_id"]!,
            predicted_height: testDynamoDBData["predicted_height"]!,
            surf_size: testDynamoDBData["surf_size"]!,
            travel_time_hours: testDynamoDBData["travel_time_hours"]!,
            confidence: testDynamoDBData["confidence"]!,
            predicted_direction: testDynamoDBData["predicted_direction"]!,
            calibration_applied: testDynamoDBData["calibration_applied"]!,
            hours_ahead: testDynamoDBData["hours_ahead"]!,
            calibration_confidence: testDynamoDBData["calibration_confidence"]!,
            predicted_period: testDynamoDBData["predicted_period"]!
        )

        let aiEntry = AIPredictedForecastEntry(from: aiResponse)
        let _ = aiEntry.toAIPredictedForecastResponse()
    }
}
