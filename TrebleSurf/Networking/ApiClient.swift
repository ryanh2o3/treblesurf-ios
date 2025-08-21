//
//  ApiClient.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import Foundation
import UIKit

// MARK: - Error Codes
enum APIClientError: Int {
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
        }
    }
}

class APIClient {
    static let shared = APIClient()
    
    // MARK: - Environment Configuration
    private var baseURL: String {
        #if DEBUG
        // Check if running on simulator vs device
        if UIDevice.current.isSimulator {
            // Simulator - use localhost
            return "http://localhost:8080"
        } else {
            // Device - always use production URL when running on physical device
            return "https://treblesurf.com"
        }
        #else
        return "https://treblesurf.com"
        #endif
    }

    // MARK: - Environment Check
    private var isDevelopmentEnvironment: Bool {
        #if DEBUG
        return UIDevice.current.isSimulator
        #else
        return false
        #endif
    }
    
    // MARK: - Server Availability Check
    func checkServerAvailability(completion: @escaping (Bool) -> Void) {
        guard isDevelopmentEnvironment else {
            // In production, assume server is always available
            completion(true)
            return
        }
        
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(false)
            return
        }
        
        let request = URLRequest(url: url, timeoutInterval: 5.0)
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                if let nsError = error as NSError? {
                    if nsError.code == NSURLErrorCannotConnectToHost || 
                       nsError.code == NSURLErrorTimedOut {
                        print("Development server not available")
                        completion(false)
                        return
                    }
                }
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    // MARK: - Mock Data for Development
    private func provideMockData<T: Decodable>(for endpoint: String, completion: @escaping (Result<T, Error>) -> Void) {
        print("Providing mock data for development endpoint: \(endpoint)")
        
        // Create appropriate mock data based on the endpoint
        if endpoint.contains("getTodaySpotReports") {
            // Mock surf reports data
            let mockReports: [SurfReportResponse] = [
                SurfReportResponse(
                    consistency: "Good",
                    imageKey: "",
                    messiness: "Clean",
                    quality: "Good",
                    reporter: "Development User",
                    surfSize: "3-4ft",
                    time: "Morning",
                    userEmail: "dev@example.com",
                    windAmount: "Light",
                    windDirection: "Offshore",
                    countryRegionSpot: "Ireland/Donegal/Ballymastocker",
                    dateReported: "2025-01-19"
                )
            ]
            
            if let mockData = mockReports as? T {
                completion(.success(mockData))
            } else {
                let error = NSError(domain: "APIClient", code: APIClientError.mockDataCreationFailed.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.mockDataCreationFailed.localizedDescription])
                completion(.failure(error))
            }
        } else {
            // Generic mock data for other endpoints
            let error = NSError(domain: "APIClient", code: APIClientError.noMockDataAvailable.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.noMockDataAvailable.localizedDescription])
            completion(.failure(error))
        }
    }

    // MARK: - Development Mode Handler
    private func handleDevelopmentMode<T: Decodable>(for endpoint: String, completion: @escaping (Result<T, Error>) -> Void) {
        print("Development mode: Server not available, providing fallback behavior")
        
        // Check if this is an endpoint that can work without the server
        if endpoint.contains("spots") || endpoint.contains("buoys") {
            // These endpoints might have local data or can work offline
            print("Development mode: Endpoint \(endpoint) might work with local data")
            // For now, just return an error, but in the future we could implement local data storage
            let error = NSError(domain: "APIClient", code: APIClientError.endpointNotAvailableOffline.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.endpointNotAvailableOffline.localizedDescription])
            completion(.failure(error))
        } else if endpoint.contains("getTodaySpotReports") || endpoint.contains("submitSurfReport") {
            // These endpoints require authentication and server interaction
            print("Development mode: Providing mock data for authenticated endpoint: \(endpoint)")
            provideMockData(for: endpoint, completion: completion)
        } else {
            // Generic fallback
            let error = NSError(domain: "APIClient", code: APIClientError.genericDevelopmentError.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.genericDevelopmentError.localizedDescription])
            completion(.failure(error))
        }
    }
    


    // MARK: - Basic Request Method
    func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Data? = nil, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            let error = NSError(domain: "APIClient", code: APIClientError.invalidURL.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.invalidURL.localizedDescription])
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add body if provided
        if let body = body {
            request.httpBody = body
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Add session cookie if available
        if let sessionCookie = AuthManager.shared.getSessionCookie() {
            for (key, value) in sessionCookie {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                // Check if we received HTML instead of JSON (indicates wrong endpoint or backend issue)
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   contentType.contains("text/html") {
                    let htmlError = NSError(domain: "APIClient", code: APIClientError.sessionValidationFailed.rawValue, userInfo: [NSLocalizedDescriptionKey: "Backend returned HTML instead of JSON - check endpoint configuration"])
                    completion(.failure(htmlError))
                    return
                }
            }
            
            guard let data = data else {
                let noDataError = NSError(domain: "APIClient", code: APIClientError.noDataReceived.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.noDataReceived.localizedDescription])
                completion(.failure(noDataError))
                return
            }
            
            // Check if response is HTML (wrong endpoint or backend issue)
            if let responseString = String(data: data, encoding: .utf8),
               responseString.contains("<!DOCTYPE html>") {
                let htmlError = NSError(domain: "APIClient", code: APIClientError.sessionValidationFailed.rawValue, userInfo: [NSLocalizedDescriptionKey: "Backend returned HTML instead of JSON - check endpoint configuration"])
                completion(.failure(htmlError))
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                // Provide better error information for debugging
                if let decodingError = error as? DecodingError {
                    print("JSON Decoding Error:")
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("  Type mismatch: Expected \(type) at \(context.codingPath)")
                        print("  Debug: \(context.debugDescription)")
                        // Print the problematic JSON data for debugging
                        if let jsonString = String(data: data, encoding: .utf8) {
                            print("  Raw JSON data: \(jsonString)")
                        }
                    case .keyNotFound(let key, let context):
                        print("  Key not found: \(key) at \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("  Value not found: Expected \(type) at \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("  Data corrupted: \(context)")
                    @unknown default:
                        print("  Unknown decoding error: \(decodingError)")
                    }
                } else {
                    print("Non-decoding error: \(error)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Authenticated Request Method
    func makeAuthenticatedRequest<T: Decodable>(to endpoint: String, method: String = "GET", body: Data? = nil, completion: @escaping (Result<T, Error>) -> Void) {
        // Check if user is authenticated
        guard AuthManager.shared.isAuthenticated else {
            let error = NSError(domain: "APIClient", code: APIClientError.userNotAuthenticated.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.userNotAuthenticated.localizedDescription])
            completion(.failure(error))
            return
        }
        
        // In development environment, check server availability first
        if isDevelopmentEnvironment {
            checkServerAvailability { serverAvailable in
                if serverAvailable {
                    // Server is available, make the request normally
                    self.request(endpoint, method: method, body: body, completion: completion)
                } else {
                    // Server is not available, handle development mode
                    self.handleDevelopmentMode(for: endpoint, completion: completion)
                }
            }
            return
        }
        
        // In production, validate session before making request
        AuthManager.shared.validateSession { success, user in
            if !success {
                let error = NSError(domain: "APIClient", code: APIClientError.sessionValidationFailed.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.sessionValidationFailed.localizedDescription])
                completion(.failure(error))
                return
            }
            
            // Make the authenticated request
            self.request(endpoint, method: method, body: body, completion: completion)
        }
    }
    
    // MARK: - POST Request with CSRF Protection
    func postRequest<T: Decodable>(to endpoint: String, body: Data, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            let error = NSError(domain: "APIClient", code: APIClientError.invalidURLForPost.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.invalidURLForPost.localizedDescription])
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add session cookie
        if let sessionCookie = AuthManager.shared.getSessionCookie() {
            for (key, value) in sessionCookie {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Add CSRF token for POST requests
        if let csrfHeader = AuthManager.shared.getCsrfHeader() {
            for (key, value) in csrfHeader {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Check HTTP status code for errors
            if let httpResponse = response as? HTTPURLResponse {
                // Handle non-success status codes
                if httpResponse.statusCode >= 400 {
                    if let data = data {
                        // Try to parse as API error response
                        if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                            let errorWithData = NSError(
                                domain: "APIClient",
                                code: httpResponse.statusCode,
                                userInfo: [
                                    NSLocalizedDescriptionKey: apiError.message,
                                    "errorData": data,
                                    "apiError": apiError
                                ]
                            )
                            completion(.failure(errorWithData))
                            return
                        }
                    }
                    
                    // If we can't parse the error, create a generic error
                    let genericError = NSError(
                        domain: "APIClient",
                        code: httpResponse.statusCode,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Request failed with status code: \(httpResponse.statusCode)"
                        ]
                    )
                    completion(.failure(genericError))
                    return
                }
            }
            
            guard let data = data else {
                let noDataError = NSError(domain: "APIClient", code: APIClientError.noDataReceivedForPost.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.noDataReceivedForPost.localizedDescription])
                completion(.failure(noDataError))
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                // Try to parse as API error response if decoding fails
                if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    let errorWithData = NSError(
                        domain: "APIClient",
                        code: 400,
                        userInfo: [
                            NSLocalizedDescriptionKey: apiError.message,
                            "errorData": data,
                            "apiError": apiError
                        ]
                    )
                    completion(.failure(errorWithData))
                } else {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Flexible Request Method
    func makeFlexibleRequest<T: Decodable>(to endpoint: String, method: String = "GET", requiresAuth: Bool = false, body: Data? = nil, completion: @escaping (Result<T, Error>) -> Void) {
        if requiresAuth {
            makeAuthenticatedRequest(to: endpoint, method: method, body: body, completion: completion)
        } else {
            // For non-authenticated requests, handle development environment gracefully
            if isDevelopmentEnvironment {
                checkServerAvailability { serverAvailable in
                    if serverAvailable {
                        // Server is available, make the request normally
                        self.request(endpoint, method: method, body: body, completion: completion)
                    } else {
                        // Server is not available, handle development mode
                        self.handleDevelopmentMode(for: endpoint, completion: completion)
                    }
                }
            } else {
                request(endpoint, method: method, body: body, completion: completion)
            }
        }
    }
    
    // MARK: - Session Management
    func validateSession(completion: @escaping (Bool) -> Void) {
        AuthManager.shared.validateSession { success, _ in
            completion(success)
        }
    }
    
    func logout(completion: @escaping (Bool) -> Void) {
        AuthManager.shared.logout(completion: completion)
    }
    
    func getSessionCookie() -> [String: String]? {
        return AuthManager.shared.getSessionCookie()
    }
    

    
    // MARK: - CSRF Token Management
    func refreshCSRFToken(completion: @escaping (Bool) -> Void) {
        print("🔄 Refreshing CSRF token...")
        
        // Make a request to get a fresh CSRF token
        guard let url = URL(string: "\(baseURL)/api/auth/csrf") else {
            print("❌ Invalid CSRF endpoint URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add session cookie if available
        if let sessionCookie = AuthManager.shared.getSessionCookie() {
            for (key, value) in sessionCookie {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Failed to refresh CSRF token: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Extract CSRF token from response headers
                    if let csrfToken = httpResponse.value(forHTTPHeaderField: "X-CSRF-Token") {
                        AuthManager.shared.csrfToken = csrfToken
                        print("✅ CSRF token refreshed: \(csrfToken.prefix(10))...")
                        completion(true)
                    } else {
                        print("⚠️  No CSRF token in response headers")
                        completion(false)
                    }
                } else {
                    print("❌ CSRF refresh failed with status: \(httpResponse.statusCode)")
                    completion(false)
                }
            } else {
                print("❌ No HTTP response received")
                completion(false)
            }
        }.resume()
    }
}

// MARK: - Surf Spots API Extensions
extension APIClient {
    func fetchSpots(country: String, region: String, completion: @escaping (Result<[SpotData], Error>) -> Void) {
        let endpoint = "/api/spots?country=\(country)&region=\(region)"
        
        request(endpoint, method: "GET") { (result: Result<[SpotData], Error>) in
            completion(result)
        }
    }
    
    // Convenience method for the specific Donegal, Ireland endpoint
    func fetchDonegalSpots(completion: @escaping (Result<[SpotData], Error>) -> Void) {
        fetchSpots(country: "Ireland", region: "Donegal", completion: completion)
    }
    
    func fetchLocationInfo(country: String, region: String, spot: String, completion: @escaping (Result<SpotData, Error>) -> Void) {
        let endpoint = "/api/locationInfo?country=\(country)&region=\(region)&spot=\(spot)"
        
        request(endpoint, method: "GET") { (result: Result<SpotData, Error>) in
            completion(result)
        }
    }
}

// MARK: - Buoys API Extensions
extension APIClient {
    func fetchBuoys(region: String, completion: @escaping (Result<[BuoyLocation], Error>) -> Void) {
        let endpoint = "/api/regionBuoys?region=\(region)"
        
        request(endpoint, method: "GET") { (result: Result<[BuoyLocation], Error>) in
            completion(result)
        }
    }
    
    func fetchBuoyData(buoyNames: [String], completion: @escaping (Result<[BuoyResponse], Error>) -> Void) {
        let buoysParam = buoyNames.joined(separator: ",")
        let endpoint = "/api/getMultipleBuoyData?buoys=\(buoysParam)"
        
        request(endpoint, method: "GET") { (result: Result<[BuoyResponse], Error>) in
            completion(result)
        }
    }
    
    func fetchLast24HoursBuoyData(buoyName: String, completion: @escaping (Result<[BuoyResponse], Error>) -> Void) {
        let endpoint = "/api/getLast24BuoyData?buoyName=\(buoyName)"
        
        request(endpoint, method: "GET") { (result: Result<[BuoyResponse], Error>) in
            completion(result)
        }
    }
}

// MARK: - Surf Reports API Extensions
extension APIClient {
    func fetchSurfReports(country: String, region: String, spot: String, completion: @escaping (Result<[SurfReportResponse], Error>) -> Void) {
        let endpoint = "/api/getTodaySpotReports?country=\(country)&region=\(region)&spot=\(spot)"
        

        
        // Use flexible request method that can handle authentication gracefully
        makeFlexibleRequest(to: endpoint, requiresAuth: true) { (result: Result<[SurfReportResponse], Error>) in
            switch result {
            case .success(let surfReport):
                completion(.success(surfReport))
            case .failure(let error):
                print("Failed to fetch surf reports: \(error.localizedDescription)")
                
                // Add debugging to see what the actual response looks like
                if let nsError = error as NSError? {
                    print("Error domain: \(nsError.domain), code: \(nsError.code)")
                    if let userInfo = nsError.userInfo as? [String: Any] {
                        print("Error user info: \(userInfo)")
                    }
                }
                
                completion(.failure(error))
            }
        }
    }
    
    func getReportImage(key: String, completion: @escaping (Result<SurfReportImageResponse, Error>) -> Void) {
        let endpoint = "/api/getReportImage?key=\(key)"
        
        // Use flexible request method that can handle authentication gracefully
        makeFlexibleRequest(to: endpoint, requiresAuth: true) { (result: Result<SurfReportImageResponse, Error>) in
            switch result {
            case .success(let reportImage):
                completion(.success(reportImage))
            case .failure(let error):
                print("Failed to fetch report image: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Current Conditions & Forecast API Extensions
extension APIClient {
    func fetchCurrentConditions(country: String, region: String, spot: String, completion: @escaping (Result<[CurrentConditionsResponse], Error>) -> Void) {
        let endpoint = "/api/currentConditions?country=\(country)&region=\(region)&spot=\(spot)"
        print("Fetching current conditions: \(spot)")
        request(endpoint, method: "GET") { (result: Result<[CurrentConditionsResponse], Error>) in
            completion(result)
        }
    }
    
    func fetchForecast(country: String, region: String, spot: String, completion: @escaping (Result<[ForecastResponse], Error>) -> Void) {
        let endpoint = "/api/forecast?country=\(country)&region=\(region)&spot=\(spot)"
        print("Fetching forecast: \(spot)")
        request(endpoint, method: "GET") { (result: Result<[ForecastResponse], Error>) in
            completion(result)
        }
    }
}
