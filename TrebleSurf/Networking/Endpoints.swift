//
//  Endpoints.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import Foundation

enum Endpoints {
    // MARK: - Authentication
    static let googleAuth = "/api/auth/google"
    static let validateToken = "/api/auth/validate"
    static let logout = "/api/auth/logout"
    static let userSessions = "/api/sessions"
    static let terminateSession = "/api/sessions/{sessionId}"
    static let webSocketToken = "/api/ws-token"
    
    // MARK: - Surf Spots
    static let spots = "/api/spots"
    static let spotForecast = "/api/forecast"
    static let spotLive = "/api/currentConditions"
    
    // MARK: - Buoys
    static let buoys = "/api/regionBuoys"
    static let buoyData = "/api/getMultipleBuoyData"
    static let singleBuoyData = "/api/getSingleBuoyData"
    static let last24BuoyData = "/api/getLast24BuoyData"
    
    // MARK: - Surf Reports
    static let surfReports = "/api/getTodaySpotReports"
    static let allSpotReports = "/api/getAllSpotReports"
    static let createSurfReport = "/api/submitSurfReport"
    static let createSurfReportWithIOSValidation = "/api/submitSurfReportWithIOSValidation"
    static let reportImage = "/api/getReportImage"
    static let generateImageUploadURL = "/api/generateImageUploadURL"
    static let generateVideoUploadURL = "/api/generateVideoUploadURL"
    static let generateVideoViewURL = "/api/generateVideoViewURL"
    static let surfReportsWithSimilarBuoyData = "/api/getSurfReportsWithSimilarBuoyData"
    
    // MARK: - Swell Predictions
    static let swellPrediction = "/api/swellPrediction"
    static let listSpotsSwellPrediction = "/api/listSpotsSwellPrediction"
    static let regionSwellPrediction = "/api/regionSwellPrediction"
    static let swellPredictionRange = "/api/swellPredictionRange"
    static let recentSwellPredictions = "/api/recentSwellPredictions"
    static let swellPredictionStatus = "/api/swellPredictionStatus"
    
    // MARK: - User Preferences
    static let userPreferences = "/api/user/preferences"
    static let updateTheme = "/api/setTheme"
    static let getTheme = "/api/getTheme"
    
    // MARK: - Helper Methods
    static func spotForecastURL(spotId: String) -> String {
        return spotForecast.replacingOccurrences(of: "{spotId}", with: spotId)
    }
    
    static func spotLiveURL(spotId: String) -> String {
        return spotLive.replacingOccurrences(of: "{spotId}", with: spotId)
    }
    
    static func buoyDataURL(buoyId: String) -> String {
        return buoyData.replacingOccurrences(of: "{buoyId}", with: buoyId)
    }
    
    static func terminateSessionURL(sessionId: String) -> String {
        return terminateSession.replacingOccurrences(of: "{sessionId}", with: sessionId)
    }
}
