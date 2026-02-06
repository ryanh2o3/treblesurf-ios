//
//  ApiClient.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import Foundation
import UIKit

// MARK: - Error Codes
enum APIClientError: Int, Error {
    case invalidURL = 1
    case noDataReceived = 2
    case userNotAuthenticated = 3
    case sessionValidationFailed = 4
    case invalidURLForPost = 5
    case noDataReceivedForPost = 6
    case developmentServerNotAvailable = 7
    case mockDataCreationFailed = 8
    case noMockDataAvailable = 9
    case endpointNotAvailableOffline = 10
    case genericDevelopmentError = 11
    case httpError = 12
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noDataReceived:
            return "No data received"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .sessionValidationFailed:
            return "Session validation failed"
        case .invalidURLForPost:
            return "Invalid URL for POST request"
        case .noDataReceivedForPost:
            return "No data received for POST request"
        case .developmentServerNotAvailable:
            return "Development server not available"
        case .mockDataCreationFailed:
            return "Failed to create mock data"
        case .noMockDataAvailable:
            return "No mock data available for this endpoint"
        case .endpointNotAvailableOffline:
            return "This endpoint is not available offline"
        case .genericDevelopmentError:
            return "Development server not available"
        case .httpError:
            return "HTTP error"
        }
    }
}

// MARK: - HTTP Error
struct HTTPError: Error {
    let statusCode: Int
    let message: String
    
    init(statusCode: Int, message: String = "HTTP Error") {
        self.statusCode = statusCode
        self.message = message
    }
}

class APIClient: APIClientProtocol {
    private let config: any AppConfigurationProtocol
    private let authManager: any AuthManagerProtocol
    private let urlSession: URLSession
    private let logger: ErrorLoggerProtocol

    init(
        config: any AppConfigurationProtocol,
        authManager: any AuthManagerProtocol,
        urlSession: URLSession = .shared,
        logger: ErrorLoggerProtocol? = nil
    ) {
        self.config = config
        self.authManager = authManager
        self.urlSession = urlSession
        self.logger = logger ?? ErrorLogger(minimumLogLevel: .debug, enableConsoleOutput: true, enableOSLog: true)
    }
    
    // MARK: - Environment Configuration
    private var baseURL: String {
        config.apiBaseURL
    }
    
    // Public method to get base URL
    var getBaseURL: String {
        return baseURL
    }

    // MARK: - Environment Check
    private var isDevelopmentEnvironment: Bool {
        #if DEBUG
        return config.isSimulator
        #else
        return false
        #endif
    }
    
    // MARK: - Server Availability Check
    func checkServerAvailability() async -> Bool {
        guard isDevelopmentEnvironment else {
            // In production, assume server is always available
            return true
        }
        
        guard let url = URL(string: "\(baseURL)/health") else {
            return false
        }
        
        let request = URLRequest(url: url, timeoutInterval: 5.0)
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            if let nsError = error as NSError? {
                if nsError.code == NSURLErrorCannotConnectToHost ||
                    nsError.code == NSURLErrorTimedOut {
                    logger.log("Development server not available", level: .warning, category: .network)
                }
            }
            return false
        }
    }
    
    // MARK: - Mock Data for Development
    private func provideMockData<T: Decodable>(for endpoint: String) throws -> T {
        logger.log("Providing mock data for development endpoint: \(endpoint)", level: .debug, category: .api)
        
        // Create appropriate mock data based on the endpoint
        if endpoint.contains("getTodaySpotReports") {
            // Mock surf reports data
            let mockReports: [SurfReportResponse] = [
                SurfReportResponse(
                    consistency: "Good",
                    imageKey: "",
                    videoKey: nil,
                    messiness: "Clean",
                    quality: "Good",
                    reporter: "Development User",
                    surfSize: "3-4ft",
                    time: "Morning",
                    userEmail: "dev@example.com",
                    windAmount: "Light",
                    windDirection: "Offshore",
                    countryRegionSpot: "Ireland/Donegal/Ballymastocker",
                    dateReported: "2025-01-19",
                    mediaType: "image",
                    iosValidated: false,
                    buoySimilarity: nil,
                    windSimilarity: nil,
                    combinedSimilarity: nil,
                    matchedBuoy: nil,
                    historicalBuoyWaveHeight: nil,
                    historicalBuoyWaveDirection: nil,
                    historicalBuoyPeriod: nil,
                    historicalWindSpeed: nil,
                    historicalWindDirection: nil,
                    travelTimeHours: nil
                )
            ]
            
            if let mockData = mockReports as? T {
                return mockData
            } else {
                throw NSError(domain: "APIClient", code: APIClientError.mockDataCreationFailed.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.mockDataCreationFailed.localizedDescription])
            }
        } else {
            // Generic mock data for other endpoints
            throw NSError(domain: "APIClient", code: APIClientError.noMockDataAvailable.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.noMockDataAvailable.localizedDescription])
        }
    }

    // MARK: - Development Mode Handler
    private func handleDevelopmentMode<T: Decodable>(for endpoint: String) throws -> T {
        logger.log("Development mode: Server not available, providing fallback behavior", level: .info, category: .api)

        // Check if this is an endpoint that can work without the server
        if endpoint.contains("spots") || endpoint.contains("buoys") {
            logger.log("Development mode: Endpoint \(endpoint) might work with local data", level: .info, category: .api)
            // For now, just return an error, but in the future we could implement local data storage
            throw NSError(domain: "APIClient", code: APIClientError.endpointNotAvailableOffline.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.endpointNotAvailableOffline.localizedDescription])
        } else if endpoint.contains("getTodaySpotReports") || endpoint.contains("submitSurfReport") {
            // These endpoints require authentication and server interaction
            logger.log("Development mode: Providing mock data for authenticated endpoint: \(endpoint)", level: .debug, category: .api)
            return try provideMockData(for: endpoint)
        } else {
            // Generic fallback
            throw NSError(domain: "APIClient", code: APIClientError.genericDevelopmentError.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.genericDevelopmentError.localizedDescription])
        }
    }
    


    // MARK: - Basic Request Method
    func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw NSError(domain: "APIClient", code: APIClientError.invalidURL.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.invalidURL.localizedDescription])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add body if provided
        if let body = body {
            request.httpBody = body
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Add session cookie if available
        if let sessionCookie = authManager.getSessionCookie() {
            for (key, value) in sessionCookie {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Add CSRF token for non-GET requests
        if method.uppercased() != "GET", let csrfHeader = authManager.getCsrfHeader() {
            for (key, value) in csrfHeader {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        let (data, response) = try await urlSession.data(for: request)
        let validatedData = try validateResponse(data: data, response: response, error: nil, context: endpoint)
        
        // Check if response is HTML (wrong endpoint or backend issue)
        if let responseString = String(data: validatedData, encoding: .utf8),
           responseString.contains("<!DOCTYPE html>") {
            throw NSError(domain: "APIClient", code: APIClientError.sessionValidationFailed.rawValue, userInfo: [NSLocalizedDescriptionKey: "Backend returned HTML instead of JSON - check endpoint configuration"])
        }
        
        return try decodeResponse(validatedData, context: endpoint)
    }
    
    // MARK: - Authenticated Request Method
    func makeAuthenticatedRequest<T: Decodable>(to endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        // Check if user is authenticated
        let isAuthenticated = await MainActor.run { authManager.isAuthenticated }
        guard isAuthenticated else {
            throw NSError(domain: "APIClient", code: APIClientError.userNotAuthenticated.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.userNotAuthenticated.localizedDescription])
        }
        
        return try await performAuthenticatedRequest(to: endpoint, method: method, body: body)
    }
    
    private func performAuthenticatedRequest<T: Decodable>(to endpoint: String, method: String, body: Data?) async throws -> T {
        // In development environment, check server availability first
        if isDevelopmentEnvironment {
            let serverAvailable = await checkServerAvailability()
            if serverAvailable {
                return try await request(endpoint, method: method, body: body)
            } else {
                return try handleDevelopmentMode(for: endpoint)
            }
        }
        
        do {
            return try await request(endpoint, method: method, body: body)
        } catch {
            // Check if this is an authentication error (401)
            if let nsError = error as NSError?,
               nsError.code == 401 {
                logger.log("Received 401, attempting session refresh", level: .warning, category: .authentication)
                let (success, _) = await authManager.validateSession()
                if success {
                    logger.log("Session refreshed, retrying original request", level: .info, category: .authentication)
                    return try await request(endpoint, method: method, body: body)
                } else {
                    logger.log("Session refresh failed, clearing auth state", level: .error, category: .authentication)
                    authManager.clearAllAppData()
                }
            }
            
            throw error
        }
    }
    
    // MARK: - POST Request with CSRF Protection
    func postRequest<T: Decodable>(to endpoint: String, body: Data) async throws -> T {
        logger.log("Starting POST request to: \(endpoint)", level: .info, category: .api)
        logger.log("Request body size: \(body.count) bytes", level: .debug, category: .api)

        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            logger.log("Invalid URL for POST request: \(baseURL)\(endpoint)", level: .error, category: .api)
            throw NSError(domain: "APIClient", code: APIClientError.invalidURLForPost.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.invalidURLForPost.localizedDescription])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add session cookie
        if let sessionCookie = authManager.getSessionCookie() {
            logger.log("Adding session cookies", level: .debug, category: .authentication)
            for (key, value) in sessionCookie {
                request.addValue(value, forHTTPHeaderField: key)
            }
        } else {
            logger.log("No session cookies available", level: .warning, category: .authentication)
        }

        // Add CSRF token for POST requests
        if let csrfHeader = authManager.getCsrfHeader() {
            logger.log("Adding CSRF token", level: .debug, category: .authentication)
            for (key, value) in csrfHeader {
                request.addValue(value, forHTTPHeaderField: key)
            }
        } else {
            logger.log("No CSRF token available", level: .warning, category: .authentication)
        }

        logger.log("Sending POST request", level: .debug, category: .api)
        let (data, response) = try await urlSession.data(for: request)
        let validatedData = try validateResponse(data: data, response: response, error: nil, context: endpoint)
        logger.log("Response data size: \(validatedData.count) bytes", level: .debug, category: .api)
        return try decodeResponse(validatedData, context: endpoint)
    }
    
    // MARK: - Flexible Request Method
    func makeFlexibleRequest<T: Decodable>(to endpoint: String, method: String = "GET", requiresAuth: Bool = false, body: Data? = nil) async throws -> T {
        if requiresAuth {
            return try await makeAuthenticatedRequest(to: endpoint, method: method, body: body)
        }
        
        // For non-authenticated requests, handle development environment gracefully
        if isDevelopmentEnvironment {
            let serverAvailable = await checkServerAvailability()
            if serverAvailable {
                return try await request(endpoint, method: method, body: body)
            } else {
                return try handleDevelopmentMode(for: endpoint)
            }
        } else {
            return try await request(endpoint, method: method, body: body)
        }
    }
    
    // MARK: - Session Management
    func validateSession() async -> Bool {
        let (success, _) = await authManager.validateSession()
        return success
    }
    
    func logout() async -> Bool {
        return await authManager.logout()
    }
    
    func getSessionCookie() -> [String: String]? {
        return authManager.getSessionCookie()
    }
    

    
    // MARK: - CSRF Token Management
    func refreshCSRFToken() async -> Bool {
        logger.log("Refreshing CSRF token", level: .info, category: .authentication)

        // Make a request to get a fresh CSRF token
        guard let url = URL(string: "\(baseURL)/api/auth/csrf") else {
            logger.log("Invalid CSRF endpoint URL", level: .error, category: .authentication)
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add session cookie if available
        if let sessionCookie = authManager.getSessionCookie() {
            for (key, value) in sessionCookie {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Extract CSRF token from response headers
                    if let csrfToken = httpResponse.value(forHTTPHeaderField: "X-CSRF-Token") {
                        authManager.updateCsrfToken(csrfToken)
                        logger.log("CSRF token refreshed successfully", level: .info, category: .authentication)
                        return true
                    } else {
                        logger.log("No CSRF token in response headers", level: .warning, category: .authentication)
                        return false
                    }
                } else {
                    logger.log("CSRF refresh failed with status: \(httpResponse.statusCode)", level: .error, category: .authentication)
                    return false
                }
            } else {
                logger.log("No HTTP response received", level: .error, category: .network)
                return false
            }
        } catch {
            logger.log("Failed to refresh CSRF token: \(error.localizedDescription)", level: .error, category: .authentication)
            return false
        }
    }
}

// MARK: - Surf Spots API Extensions
// Logic moved to SpotService
extension APIClient {
    // Kept empty or remove extension entirely?
    // Removing methods as per plan.
}

// MARK: - Buoys API Extensions
extension APIClient {
    func fetchBuoys(region: String) async throws -> [BuoyLocation] {
        let endpoint = "/api/regionBuoys?region=\(region)"
        return try await request(endpoint, method: "GET")
    }
    
    func fetchBuoyData(buoyNames: [String]) async throws -> [BuoyResponse] {
        let buoysParam = buoyNames.joined(separator: ",")
        
        // URL encode the buoys parameter to handle spaces and special characters
        guard let encodedBuoysParam = buoysParam.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NSError(domain: "APIClient", code: APIClientError.invalidURL.rawValue, userInfo: [NSLocalizedDescriptionKey: "Failed to URL encode buoy names: \(buoysParam)"])
        }
        
        let endpoint = "/api/getMultipleBuoyData?buoys=\(encodedBuoysParam)"
        
        logger.log("Fetching buoy data for: \(buoyNames)", level: .debug, category: .api)
        
        return try await request(endpoint, method: "GET")
    }
    
    func fetchLast24HoursBuoyData(buoyName: String) async throws -> [BuoyResponse] {
        // URL encode the buoy name to handle spaces and special characters
        guard let encodedBuoyName = buoyName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NSError(domain: "APIClient", code: APIClientError.invalidURL.rawValue, userInfo: [NSLocalizedDescriptionKey: "Failed to URL encode buoy name: \(buoyName)"])
        }
        
        let endpoint = "/api/getLast24BuoyData?buoyName=\(encodedBuoyName)"
        
        logger.log("Fetching historical data for buoy: \(buoyName)", level: .debug, category: .api)
        
        return try await request(endpoint, method: "GET")
    }
    
    func fetchBuoyDataRange(buoyName: String, startDate: Date, endDate: Date) async throws -> [BuoyResponse] {
        // URL encode the buoy name to handle spaces and special characters
        guard let encodedBuoyName = buoyName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NSError(domain: "APIClient", code: APIClientError.invalidURL.rawValue, userInfo: [NSLocalizedDescriptionKey: "Failed to URL encode buoy name: \(buoyName)"])
        }
        
        // Format dates to ISO8601 format (2006-01-02T15:04:05Z)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let startTimeStr = formatter.string(from: startDate)
        let endTimeStr = formatter.string(from: endDate)
        
        guard let encodedStartTime = startTimeStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedEndTime = endTimeStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NSError(domain: "APIClient", code: APIClientError.invalidURL.rawValue, userInfo: [NSLocalizedDescriptionKey: "Failed to URL encode date parameters"])
        }
        
        let endpoint = "/api/getBuoyDataRange?buoyName=\(encodedBuoyName)&startTime=\(encodedStartTime)&endTime=\(encodedEndTime)"
        
        logger.log("Fetching buoy data range for: \(buoyName) from \(startTimeStr) to \(endTimeStr)", level: .debug, category: .api)
        
        return try await request(endpoint, method: "GET")
    }
}

// MARK: - Surf Reports API Extensions
extension APIClient {
    // fetchSurfReports, fetchAllSpotReports, getReportImage/Video moved to SurfReportService
    
    func fetchSurfReportsWithSimilarBuoyData(
        waveHeight: Double,
        waveDirection: Double,
        period: Double,
        buoyName: String,
        country: String? = nil,
        region: String? = nil,
        spot: String? = nil,
        daysBack: Int = 365,
        maxResults: Int = 20
    ) async throws -> [SurfReportResponse] {
        var queryParams = [
            "waveHeight=\(waveHeight)",
            "waveDirection=\(waveDirection)",
            "period=\(period)",
            "buoyName=\(buoyName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? buoyName)",
            "daysBack=\(daysBack)",
            "maxResults=\(maxResults)"
        ]
        
        if let country = country {
            queryParams.append("country=\(country.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? country)")
        }
        if let region = region {
            queryParams.append("region=\(region.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? region)")
        }
        if let spot = spot {
            queryParams.append("spot=\(spot.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? spot)")
        }
        
        let endpoint = "\(Endpoints.surfReportsWithSimilarBuoyData)?\(queryParams.joined(separator: "&"))"
        
        logger.log("Fetching surf reports with similar buoy data: \(buoyName)", level: .info, category: .api)
        
        return try await makeFlexibleRequest(to: endpoint, requiresAuth: true)
    }
    
    // Protocol conformance overload
    func fetchSurfReportsWithSimilarBuoyData(
        waveHeight: Double,
        waveDirection: Double,
        period: Double,
        buoyName: String,
        maxResults: Int
    ) async throws -> [SurfReportResponse] {
        return try await fetchSurfReportsWithSimilarBuoyData(
            waveHeight: waveHeight,
            waveDirection: waveDirection,
            period: period,
            buoyName: buoyName,
            country: nil,
            region: nil,
            spot: nil,
            daysBack: 365,
            maxResults: maxResults
        )
    }
    
    func fetchSurfReportsWithMatchingConditions(
        country: String,
        region: String,
        spot: String,
        daysBack: Int = 365,
        maxResults: Int = 20
    ) async throws -> [SurfReportResponse] {
        let queryParams = [
            "country=\(country.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? country)",
            "region=\(region.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? region)",
            "spot=\(spot.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? spot)",
            "daysBack=\(daysBack)",
            "maxResults=\(maxResults)"
        ]
        
        let endpoint = "/api/getSurfReportsWithMatchingConditions?\(queryParams.joined(separator: "&"))"
        
        logger.log("Fetching surf reports with matching conditions for: \(spot)", level: .info, category: .api)
        
        return try await makeFlexibleRequest(to: endpoint, requiresAuth: true)
    }
    
}

// MARK: - Current Conditions & Forecast API Extensions
extension APIClient {
    func fetchCurrentConditions(country: String, region: String, spot: String) async throws -> [CurrentConditionsResponse] {
        let endpoint = "/api/currentConditions?country=\(country)&region=\(region)&spot=\(spot)"
        logger.log("Fetching current conditions: \(spot)", level: .debug, category: .api)
        return try await request(endpoint, method: "GET")
    }
    
    func fetchForecast(country: String, region: String, spot: String) async throws -> [ForecastResponse] {
        let endpoint = "/api/forecast?country=\(country)&region=\(region)&spot=\(spot)"
        logger.log("Fetching forecast: \(spot)", level: .debug, category: .api)
        return try await request(endpoint, method: "GET")
    }
}

// MARK: - Swell Prediction API Extensions
extension APIClient {
    func fetchSwellPrediction(country: String, region: String, spot: String) async throws -> [SwellPredictionResponse] {
        let endpoint = "\(Endpoints.swellPrediction)?spot=\(spot)&region=\(region)&country=\(country)"
        logger.log("Fetching swell prediction: \(spot)", level: .debug, category: .api)
        return try await request(endpoint, method: "GET")
    }

    /// Fetch swell prediction in DynamoDB format
    func fetchSwellPredictionDynamoDB(country: String, region: String, spot: String) async throws -> [String: DynamoDBAttributeValue] {
        let endpoint = "\(Endpoints.swellPrediction)?spot=\(spot)&region=\(region)&country=\(country)"
        logger.log("Fetching swell prediction (DynamoDB format): \(spot)", level: .debug, category: .api)
        
        // Create URL
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw APIClientError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add session cookie if available
        if let sessionCookie = authManager.getSessionCookie() {
            for (key, value) in sessionCookie {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        let (data, _) = try await urlSession.data(for: request)
        // Try to parse as array of SwellPredictionResponse first (new format)
        if let responses = try? JSONDecoder().decode([SwellPredictionResponse].self, from: data) {
            // Convert first response to DynamoDB format for backward compatibility
            guard let firstResponse = responses.first else {
                throw APIClientError.noDataReceived
            }
            return [
                "spot_id": DynamoDBAttributeValue(stringValue: firstResponse.spot_id, numberValue: nil, booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "forecast_timestamp": DynamoDBAttributeValue(stringValue: firstResponse.forecast_timestamp, numberValue: nil, booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "generated_at": DynamoDBAttributeValue(stringValue: firstResponse.generated_at, numberValue: nil, booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "predicted_height": DynamoDBAttributeValue(stringValue: nil, numberValue: String(firstResponse.predicted_height), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "predicted_period": DynamoDBAttributeValue(stringValue: nil, numberValue: String(firstResponse.predicted_period), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "predicted_direction": DynamoDBAttributeValue(stringValue: nil, numberValue: String(firstResponse.predicted_direction), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "surf_size": DynamoDBAttributeValue(stringValue: nil, numberValue: String(firstResponse.surf_size), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "travel_time_hours": DynamoDBAttributeValue(stringValue: nil, numberValue: String(firstResponse.travel_time_hours), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "arrival_time": DynamoDBAttributeValue(stringValue: firstResponse.arrival_time, numberValue: nil, booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "direction_quality": DynamoDBAttributeValue(stringValue: nil, numberValue: String(firstResponse.direction_quality), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "calibration_applied": DynamoDBAttributeValue(stringValue: nil, numberValue: String(firstResponse.calibration_applied ? 1 : 0), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "calibration_confidence": DynamoDBAttributeValue(stringValue: nil, numberValue: String(firstResponse.calibration_confidence), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "confidence": DynamoDBAttributeValue(stringValue: nil, numberValue: String(firstResponse.confidence), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "distance_km": DynamoDBAttributeValue(stringValue: nil, numberValue: String(firstResponse.distance_km), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
                "hours_ahead": DynamoDBAttributeValue(stringValue: nil, numberValue: String(firstResponse.hours_ahead ?? 0.0), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil)
            ]
        }
        
        // Fallback to single response format
        let response = try JSONDecoder().decode(SwellPredictionResponse.self, from: data)
        return [
            "spot_id": DynamoDBAttributeValue(stringValue: response.spot_id, numberValue: nil, booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "forecast_timestamp": DynamoDBAttributeValue(stringValue: response.forecast_timestamp, numberValue: nil, booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "generated_at": DynamoDBAttributeValue(stringValue: response.generated_at, numberValue: nil, booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "predicted_height": DynamoDBAttributeValue(stringValue: nil, numberValue: String(response.predicted_height), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "predicted_period": DynamoDBAttributeValue(stringValue: nil, numberValue: String(response.predicted_period), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "predicted_direction": DynamoDBAttributeValue(stringValue: nil, numberValue: String(response.predicted_direction), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "surf_size": DynamoDBAttributeValue(stringValue: nil, numberValue: String(response.surf_size), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "travel_time_hours": DynamoDBAttributeValue(stringValue: nil, numberValue: String(response.travel_time_hours), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "arrival_time": DynamoDBAttributeValue(stringValue: response.arrival_time, numberValue: nil, booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "direction_quality": DynamoDBAttributeValue(stringValue: nil, numberValue: String(response.direction_quality), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "calibration_applied": DynamoDBAttributeValue(stringValue: nil, numberValue: String(response.calibration_applied ? 1 : 0), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "calibration_confidence": DynamoDBAttributeValue(stringValue: nil, numberValue: String(response.calibration_confidence), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "confidence": DynamoDBAttributeValue(stringValue: nil, numberValue: String(response.confidence), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "distance_km": DynamoDBAttributeValue(stringValue: nil, numberValue: String(response.distance_km), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil),
            "hours_ahead": DynamoDBAttributeValue(stringValue: nil, numberValue: String(response.hours_ahead ?? 0.0), booleanValue: nil, binaryValue: nil, stringSetValue: nil, numberSetValue: nil, binarySetValue: nil, listValue: nil, mapValue: nil, nullValue: nil)
        ]
    }
    
    func fetchMultipleSpotsSwellPrediction(country: String, region: String, spots: [String]) async throws -> [[SwellPredictionResponse]] {
        let spotsParam = spots.joined(separator: ",")
        let endpoint = "\(Endpoints.listSpotsSwellPrediction)?spots=\(spotsParam)&region=\(region)&country=\(country)"
        logger.log("Fetching swell predictions for multiple spots: \(spots)", level: .debug, category: .api)
        return try await request(endpoint, method: "GET")
    }
    
    func fetchRegionSwellPrediction(country: String, region: String) async throws -> [SwellPredictionResponse] {
        let endpoint = "\(Endpoints.regionSwellPrediction)?region=\(region)&country=\(country)"
        logger.log("Fetching region swell predictions: \(region)", level: .debug, category: .api)
        return try await request(endpoint, method: "GET")
    }
    
    func fetchSwellPredictionRange(country: String, region: String, spot: String, startTime: Date, endTime: Date) async throws -> [SwellPredictionResponse] {
        let dateFormatter = ISO8601DateFormatter()
        let startTimeString = dateFormatter.string(from: startTime)
        let endTimeString = dateFormatter.string(from: endTime)
        
        let endpoint = "\(Endpoints.swellPredictionRange)?spot=\(spot)&region=\(region)&country=\(country)&startTime=\(startTimeString)&endTime=\(endTimeString)"
        logger.log("Fetching swell prediction range: \(spot) from \(startTimeString) to \(endTimeString)", level: .debug, category: .api)
        return try await request(endpoint, method: "GET")
    }
    
    func fetchRecentSwellPredictions(hours: Int = 24) async throws -> [SwellPredictionResponse] {
        let endpoint = "\(Endpoints.recentSwellPredictions)?hours=\(hours)"
        logger.log("Fetching recent swell predictions: last \(hours) hours", level: .debug, category: .api)
        return try await request(endpoint, method: "GET")
    }
    
    func fetchSwellPredictionStatus() async throws -> SwellPredictionStatusResponse {
        let endpoint = Endpoints.swellPredictionStatus
        logger.log("Fetching swell prediction status", level: .debug, category: .api)
        return try await request(endpoint, method: "GET")
    }
    
    func fetchClosestAIPrediction(country: String, region: String, spot: String) async throws -> SwellPredictionResponse {
        let endpoint = "/api/closestAIPrediction?spot=\(spot)&region=\(region)&country=\(country)"
        logger.log("Fetching closest AI prediction: \(spot)", level: .debug, category: .api)
        return try await request(endpoint, method: "GET")
    }
}
