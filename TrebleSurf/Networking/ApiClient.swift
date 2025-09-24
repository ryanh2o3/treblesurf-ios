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
    
    // Public method to get base URL
    var getBaseURL: String {
        return baseURL
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
                    iosValidated: false
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
        
        // Make the authenticated request directly - let the backend return 401 if session is invalid
        self.request(endpoint, method: method, body: body) { (result: Result<T, Error>) in
            switch result {
            case .success(let data):
                completion(.success(data))
            case .failure(let error):
                // Check if this is an authentication error (401)
                if let nsError = error as NSError?,
                   nsError.code == 401 {
                    print("🔐 Received 401, attempting session refresh...")
                    
                    // Try to refresh the session
                    AuthManager.shared.validateSession { success, user in
                        if success {
                            print("✅ Session refreshed, retrying original request...")
                            // Retry the original request
                            self.request(endpoint, method: method, body: body, completion: completion)
                        } else {
                            print("❌ Session refresh failed, clearing auth state")
                            // Clear auth state and return the original error
                            DispatchQueue.main.async {
                                AuthManager.shared.clearAllAppData()
                            }
                            completion(.failure(error))
                        }
                    }
                } else {
                    // Not an auth error, return the original error
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - POST Request with CSRF Protection
    func postRequest<T: Decodable>(to endpoint: String, body: Data, completion: @escaping (Result<T, Error>) -> Void) {
        print("🌐 [API_CLIENT] Starting POST request to: \(endpoint)")
        print("📦 [API_CLIENT] Request body size: \(body.count) bytes")
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            print("❌ [API_CLIENT] Invalid URL for POST request: \(baseURL)\(endpoint)")
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
            print("🍪 [API_CLIENT] Adding session cookies")
            for (key, value) in sessionCookie {
                request.addValue(value, forHTTPHeaderField: key)
                print("🍪 [API_CLIENT] Cookie: \(key) = \(value.prefix(20))...")
            }
        } else {
            print("⚠️ [API_CLIENT] No session cookies available")
        }
        
        // Add CSRF token for POST requests
        if let csrfHeader = AuthManager.shared.getCsrfHeader() {
            print("🔐 [API_CLIENT] Adding CSRF token")
            for (key, value) in csrfHeader {
                request.addValue(value, forHTTPHeaderField: key)
                print("🔐 [API_CLIENT] CSRF: \(key) = \(value.prefix(10))...")
            }
        } else {
            print("⚠️ [API_CLIENT] No CSRF token available")
        }
        
        print("🚀 [API_CLIENT] Sending POST request...")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [API_CLIENT] Network error: \(error)")
                if let nsError = error as NSError? {
                    print("❌ [API_CLIENT] Error details:")
                    print("   - Domain: \(nsError.domain)")
                    print("   - Code: \(nsError.code)")
                    print("   - Description: \(nsError.localizedDescription)")
                }
                completion(.failure(error))
                return
            }
            
            // Check HTTP status code for errors
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 [API_CLIENT] HTTP response status: \(httpResponse.statusCode)")
                
                // Handle non-success status codes
                if httpResponse.statusCode >= 400 {
                    print("❌ [API_CLIENT] HTTP error status: \(httpResponse.statusCode)")
                    
                    if let data = data {
                        print("📄 [API_CLIENT] Error response data size: \(data.count) bytes")
                        
                        // Try to parse as API error response
                        if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                            print("🚨 [API_CLIENT] Parsed API error response:")
                            print("   - Error: \(apiError.error)")
                            print("   - Message: \(apiError.message)")
                            print("   - Help: \(apiError.help)")
                            
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
                        } else {
                            print("⚠️ [API_CLIENT] Could not parse as API error response")
                            if let responseString = String(data: data, encoding: .utf8) {
                                print("📄 [API_CLIENT] Raw response: \(responseString.prefix(200))...")
                            }
                        }
                    }
                    
                    // If we can't parse the error, create a generic error
                    print("❌ [API_CLIENT] Creating generic error for status: \(httpResponse.statusCode)")
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
                print("❌ [API_CLIENT] No data received in response")
                let noDataError = NSError(domain: "APIClient", code: APIClientError.noDataReceivedForPost.rawValue, userInfo: [NSLocalizedDescriptionKey: APIClientError.noDataReceivedForPost.localizedDescription])
                completion(.failure(noDataError))
                return
            }
            
            print("📦 [API_CLIENT] Response data size: \(data.count) bytes")
            
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                print("✅ [API_CLIENT] Successfully decoded response")
                completion(.success(decoded))
            } catch {
                print("❌ [API_CLIENT] Failed to decode response: \(error)")
                
                // Try to parse as API error response if decoding fails
                if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    print("🚨 [API_CLIENT] Decoded as API error response:")
                    print("   - Error: \(apiError.error)")
                    print("   - Message: \(apiError.message)")
                    print("   - Help: \(apiError.help)")
                    
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
                    print("❌ [API_CLIENT] Could not decode as API error either")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📄 [API_CLIENT] Raw response: \(responseString.prefix(200))...")
                    }
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
        
        // URL encode the buoys parameter to handle spaces and special characters
        guard let encodedBuoysParam = buoysParam.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            let error = NSError(domain: "APIClient", code: APIClientError.invalidURL.rawValue, userInfo: [NSLocalizedDescriptionKey: "Failed to URL encode buoy names: \(buoysParam)"])
            completion(.failure(error))
            return
        }
        
        let endpoint = "/api/getMultipleBuoyData?buoys=\(encodedBuoysParam)"
        
        print("Debug: Fetching buoy data with endpoint: \(endpoint)")
        print("Debug: Original buoy names: \(buoyNames)")
        print("Debug: Encoded buoys param: \(encodedBuoysParam)")
        
        request(endpoint, method: "GET") { (result: Result<[BuoyResponse], Error>) in
            completion(result)
        }
    }
    
    func fetchLast24HoursBuoyData(buoyName: String, completion: @escaping (Result<[BuoyResponse], Error>) -> Void) {
        // URL encode the buoy name to handle spaces and special characters
        guard let encodedBuoyName = buoyName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            let error = NSError(domain: "APIClient", code: APIClientError.invalidURL.rawValue, userInfo: [NSLocalizedDescriptionKey: "Failed to URL encode buoy name: \(buoyName)"])
            completion(.failure(error))
            return
        }
        
        let endpoint = "/api/getLast24BuoyData?buoyName=\(encodedBuoyName)"
        
        print("Debug: Fetching historical data for buoy: \(buoyName) -> encoded: \(encodedBuoyName)")
        
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
        
        print("📷 [API_CLIENT] Fetching report image for key: \(key)")
        
        // Use flexible request method that can handle authentication gracefully
        makeFlexibleRequest(to: endpoint, requiresAuth: true) { (result: Result<SurfReportImageResponse, Error>) in
            switch result {
            case .success(let reportImage):
                if let imageData = reportImage.imageData {
                    print("✅ [API_CLIENT] Successfully fetched report image with data length: \(imageData.count)")
                } else {
                    print("⚠️ [API_CLIENT] Report image response received but imageData is nil")
                }
                completion(.success(reportImage))
            case .failure(let error):
                print("❌ [API_CLIENT] Failed to fetch report image: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func getReportVideo(key: String, completion: @escaping (Result<SurfReportVideoResponse, Error>) -> Void) {
        let endpoint = "/api/getReportVideo?key=\(key)"
        
        // Use flexible request method that can handle authentication gracefully
        makeFlexibleRequest(to: endpoint, requiresAuth: true) { (result: Result<SurfReportVideoResponse, Error>) in
            switch result {
            case .success(let reportVideo):
                completion(.success(reportVideo))
            case .failure(let error):
                print("Failed to fetch report video: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func getVideoViewURL(key: String, completion: @escaping (Result<PresignedVideoViewResponse, Error>) -> Void) {
        let endpoint = "\(Endpoints.generateVideoViewURL)?key=\(key)"
        
        print("🎬 [API_CLIENT] Getting video view URL for key: \(key)")
        
        makeFlexibleRequest(to: endpoint, requiresAuth: true) { (result: Result<PresignedVideoViewResponse, Error>) in
            switch result {
            case .success(let viewResponse):
                if let viewURL = viewResponse.viewURL {
                    print("✅ [API_CLIENT] Video view URL generated successfully: \(viewURL.prefix(50))...")
                } else {
                    print("⚠️ [API_CLIENT] Video view URL response received but viewURL is nil")
                }
                completion(.success(viewResponse))
            case .failure(let error):
                print("❌ [API_CLIENT] Failed to get video view URL: \(error.localizedDescription)")
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

// MARK: - Swell Prediction API Extensions
extension APIClient {
    func fetchSwellPrediction(country: String, region: String, spot: String, completion: @escaping (Result<SwellPredictionResponse, Error>) -> Void) {
        let endpoint = "\(Endpoints.swellPrediction)?spot=\(spot)&region=\(region)&country=\(country)"
        print("Fetching swell prediction: \(spot)")
        request(endpoint, method: "GET") { (result: Result<SwellPredictionResponse, Error>) in
            completion(result)
        }
    }
    
    /// Fetch swell prediction in DynamoDB format
    func fetchSwellPredictionDynamoDB(country: String, region: String, spot: String, completion: @escaping (Result<[String: DynamoDBAttributeValue], Error>) -> Void) {
        let endpoint = "\(Endpoints.swellPrediction)?spot=\(spot)&region=\(region)&country=\(country)"
        print("Fetching swell prediction (DynamoDB format): \(spot)")
        
        // Create URL
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            completion(.failure(APIClientError.invalidURL))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add session cookie if available
        if let sessionCookie = AuthManager.shared.getSessionCookie() {
            for (key, value) in sessionCookie {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Perform request
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(APIClientError.noDataReceived))
                    return
                }
                
                do {
                    // Try to parse as DynamoDB format first
                    if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dynamoDBData = jsonObject as? [String: DynamoDBAttributeValue] {
                        completion(.success(dynamoDBData))
                    } else {
                        // Fallback to regular format
                        let response = try JSONDecoder().decode(SwellPredictionResponse.self, from: data)
                        // Convert to DynamoDB format
                        let dynamoDBData: [String: DynamoDBAttributeValue] = [
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
                        completion(.success(dynamoDBData))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func fetchMultipleSpotsSwellPrediction(country: String, region: String, spots: [String], completion: @escaping (Result<[[SwellPredictionResponse]], Error>) -> Void) {
        let spotsParam = spots.joined(separator: ",")
        let endpoint = "\(Endpoints.listSpotsSwellPrediction)?spots=\(spotsParam)&region=\(region)&country=\(country)"
        print("Fetching swell predictions for multiple spots: \(spots)")
        request(endpoint, method: "GET") { (result: Result<[[SwellPredictionResponse]], Error>) in
            completion(result)
        }
    }
    
    func fetchRegionSwellPrediction(country: String, region: String, completion: @escaping (Result<[SwellPredictionResponse], Error>) -> Void) {
        let endpoint = "\(Endpoints.regionSwellPrediction)?region=\(region)&country=\(country)"
        print("Fetching region swell predictions: \(region)")
        request(endpoint, method: "GET") { (result: Result<[SwellPredictionResponse], Error>) in
            completion(result)
        }
    }
    
    func fetchSwellPredictionRange(country: String, region: String, spot: String, startTime: Date, endTime: Date, completion: @escaping (Result<[SwellPredictionResponse], Error>) -> Void) {
        let dateFormatter = ISO8601DateFormatter()
        let startTimeString = dateFormatter.string(from: startTime)
        let endTimeString = dateFormatter.string(from: endTime)
        
        let endpoint = "\(Endpoints.swellPredictionRange)?spot=\(spot)&region=\(region)&country=\(country)&startTime=\(startTimeString)&endTime=\(endTimeString)"
        print("Fetching swell prediction range: \(spot) from \(startTimeString) to \(endTimeString)")
        request(endpoint, method: "GET") { (result: Result<[SwellPredictionResponse], Error>) in
            completion(result)
        }
    }
    
    func fetchRecentSwellPredictions(hours: Int = 24, completion: @escaping (Result<[SwellPredictionResponse], Error>) -> Void) {
        let endpoint = "\(Endpoints.recentSwellPredictions)?hours=\(hours)"
        print("Fetching recent swell predictions: last \(hours) hours")
        request(endpoint, method: "GET") { (result: Result<[SwellPredictionResponse], Error>) in
            completion(result)
        }
    }
    
    func fetchSwellPredictionStatus(completion: @escaping (Result<SwellPredictionStatusResponse, Error>) -> Void) {
        let endpoint = Endpoints.swellPredictionStatus
        print("Fetching swell prediction status")
        request(endpoint, method: "GET") { (result: Result<SwellPredictionStatusResponse, Error>) in
            completion(result)
        }
    }
}
