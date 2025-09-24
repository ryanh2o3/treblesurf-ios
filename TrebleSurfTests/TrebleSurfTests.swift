//
//  TrebleSurfTests.swift
//  TrebleSurfTests
//
//  Created by Ryan Patton on 03/05/2025.
//

import Testing
@testable import TrebleSurf

struct TrebleSurfTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test func testSwellPredictionParsing() async throws {
        let testJSON = """
        [
            {
                "arrival_time": "2025-09-25T01:00:00",
                "calibration_applied": 0,
                "calibration_confidence": 1,
                "calibration_factor": {
                    "confidence_boost": 1,
                    "height_factor": 1,
                    "method": "no_similar_reports",
                    "surf_size_factor": 1
                },
                "confidence": 1,
                "direction_quality": 0,
                "distance_km": 98.907205,
                "forecast_timestamp": "1758762000",
                "generated_at": "1758744448",
                "hours_ahead": 0,
                "predicted_direction": -123.657566,
                "predicted_height": 0.680022,
                "predicted_period": 9.059257,
                "reports_analyzed": 8,
                "spot_id": "Ireland#Donegal#Ballyhiernan",
                "surf_size": 0.787617,
                "travel_time_hours": 5.851329
            }
        ]
        """
        
        let data = testJSON.data(using: .utf8)!
        let responses = try JSONDecoder().decode([SwellPredictionResponse].self, from: data)
        
        #expect(responses.count == 1)
        
        let response = responses[0]
        #expect(response.spot_id == "Ireland#Donegal#Ballyhiernan")
        #expect(response.arrival_time == "2025-09-25T01:00:00")
        #expect(response.surf_size == 0.787617)
        #expect(response.confidence == 1.0)
        #expect(response.hours_ahead == 0)
        #expect(response.reports_analyzed == 8)
        
        // Test conversion to SwellPredictionEntry
        let entry = SwellPredictionEntry(from: response)
        #expect(entry.spotId == "Ireland#Donegal#Ballyhiernan")
        #expect(entry.surfSize == 0.787617)
        #expect(entry.confidence == 1.0)
        #expect(entry.hoursAhead == 0)
        #expect(entry.reportsAnalyzed == 8)
    }

}
