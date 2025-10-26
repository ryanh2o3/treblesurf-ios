//
//  DataFormatter.swift
//  TrebleSurf
//
//  Created by Cursor
//

import Foundation

/// Service for formatting and transforming data
struct DataFormatter {
    private init() {}
    
    // MARK: - Wave Height
    
    /// Format wave height as string with units
    /// - Parameter height: Wave height in meters
    /// - Returns: Formatted string (e.g., "3.5m")
    static func formatWaveHeight(_ height: Double) -> String {
        return String(format: "%.1fm", height)
    }
    
    // MARK: - Wind Direction
    
    /// Convert wind direction from degrees to cardinal direction
    /// - Parameter degrees: Wind direction in degrees (0-360)
    /// - Returns: Cardinal direction string (e.g., "N", "NE", "E")
    static func getWindDirectionString(from degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees + 11.25) / 22.5) % 16
        return directions[index]
    }
    
    /// Format wind direction as degrees
    /// - Parameter degrees: Wind direction in degrees (0-360)
    /// - Returns: Formatted string (e.g., "45°")
    static func formatWindDirection(_ degrees: Int) -> String {
        return degrees > 0 ? String(format: "%d°", degrees) : "N/A"
    }
    
    // MARK: - Wind Speed
    
    /// Convert wind speed from m/s to km/h and format
    /// - Parameter windSpeed: Wind speed in m/s
    /// - Returns: Formatted string (e.g., "15 km/h")
    static func formatWindSpeed(_ windSpeed: Double) -> String {
        let windSpeedInKmh = windSpeed * 3.6
        return String(format: "%.0f km/h", windSpeedInKmh)
    }
    
    // MARK: - Temperature
    
    /// Format temperature in Celsius
    /// - Parameter temperature: Temperature in Celsius
    /// - Returns: Formatted string (e.g., "18°C")
    static func formatTemperature(_ temperature: Double) -> String {
        return String(format: "%.0f°C", temperature)
    }
    
    // MARK: - Wave Period
    
    /// Format wave period
    /// - Parameter period: Wave period in seconds
    /// - Returns: Formatted string (e.g., "8s") or "N/A" if invalid
    static func formatWavePeriod(_ period: Double) -> String {
        let validPeriod = period.isFinite && period >= 0 ? period : 0.0
        return validPeriod > 0 ? String(format: "%.1fs", validPeriod) : "N/A"
    }
    
    // MARK: - Validators
    
    /// Validate and sanitize numeric value
    /// - Parameters:
    ///   - value: The value to validate
    ///   - min: Minimum valid value (default: 0)
    /// - Returns: Valid value or 0 if invalid
    static func validateNumericValue(_ value: Double, min: Double = 0) -> Double {
        return value.isFinite && value >= min ? value : 0.0
    }
    
    /// Validate wind/wave direction
    /// - Parameter degrees: Direction in degrees
    /// - Returns: Valid direction or 0 if invalid
    static func validateDirection(_ degrees: Int) -> Int {
        return (0...360).contains(degrees) ? degrees : 0
    }
    
    // MARK: - Spot Name
    
    /// Extract just the spot name from countryRegionSpot format
    /// - Parameter countryRegionSpot: Full spot identifier (e.g., "Ireland_Donegal_Ballyhiernan")
    /// - Returns: Just the spot name (e.g., "Ballyhiernan")
    static func extractSpotName(from countryRegionSpot: String) -> String {
        return countryRegionSpot.components(separatedBy: "_").last ?? countryRegionSpot
    }
}

