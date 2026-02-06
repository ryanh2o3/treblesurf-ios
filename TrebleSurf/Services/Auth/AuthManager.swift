//
//  AuthManager.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import GoogleSignIn
import SwiftUI
import UIKit

@MainActor
class AuthManager: ObservableObject, AuthManagerProtocol {
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    
    private weak var dataStore: (any DataStoreProtocol)?
    private weak var locationStore: (any LocationStoreProtocol)?
    private weak var settingsStore: (any SettingsStoreProtocol)?

    // Safety: Immutable service reference assigned once during init and never mutated.
    nonisolated(unsafe) private let keychain: KeychainHelper
    // Safety: Immutable service reference assigned once during init and never mutated.
    nonisolated(unsafe) private let logger: ErrorLoggerProtocol
    private let csrfKey = "com.treblesurf.csrfToken"
    private let sessionKey = "com.treblesurf.sessionId"

    nonisolated var csrfToken: String? {
        get {
            return keychain.retrieve(key: csrfKey)
        }
        set {
            if let token = newValue {
                keychain.save(key: csrfKey, value: token)
            } else {
                keychain.delete(key: csrfKey)
            }
        }
    }

    nonisolated var sessionId: String? {
        get {
            return keychain.retrieve(key: sessionKey)
        }
        set {
            if let token = newValue {
                keychain.save(key: sessionKey, value: token)
            } else {
                keychain.delete(key: sessionKey)
            }
        }
    }
    
    var csrfTokenValue: String? {
        get {
            return csrfToken
        }
        set {
            csrfToken = newValue
        }
    }
    
    // MARK: - Initialization

    nonisolated init(keychain: KeychainHelper = KeychainHelper(), logger: ErrorLoggerProtocol? = nil) {
        self.keychain = keychain
        self.logger = logger ?? ErrorLogger(minimumLogLevel: .debug, enableConsoleOutput: true, enableOSLog: true)
    }
    
    func setStores(
        dataStore: any DataStoreProtocol,
        locationStore: any LocationStoreProtocol,
        settingsStore: any SettingsStoreProtocol
    ) {
        self.dataStore = dataStore
        self.locationStore = locationStore
        self.settingsStore = settingsStore
    }
    
    // MARK: - Authentication Methods
    
    /// Check if we have any stored authentication data
    nonisolated func hasStoredAuthData() -> Bool {
        return (sessionId != nil && !sessionId!.isEmpty) || 
               (csrfToken != nil && !csrfToken!.isEmpty)
    }
    
    /// Debug method to print current authentication state
    func debugPrintAuthState() {
        logger.log("=== Authentication State ===", level: .debug, category: .authentication)
        logger.log("Device: \(UIDevice.current.isSimulator ? "Simulator" : "Physical Device")", level: .debug, category: .authentication)
        logger.log("Session ID: \(sessionId ?? "None")", level: .debug, category: .authentication)
        logger.log("CSRF Token: \(csrfToken != nil ? "Present (\(csrfToken!.prefix(10)))..." : "None")", level: .debug, category: .authentication)
        logger.log("Current User: \(currentUser?.email ?? "None")", level: .debug, category: .authentication)
        logger.log("Is Authenticated: \(isAuthenticated)", level: .debug, category: .authentication)
        logger.log("================================", level: .debug, category: .authentication)
    }
    
    func authenticateWithBackend(user: GIDGoogleUser) async -> (Bool, User?) {
        logger.log("Starting Google authentication with backend...", level: .debug, category: .authentication)
        logger.log("Google user: \(user.profile?.email ?? "Unknown email")", level: .debug, category: .authentication)
        
        guard let idToken = user.idToken?.tokenString else {
            logger.log("No ID token available from Google user", level: .error, category: .authentication)
            return (false, nil)
        }
        
        logger.log("ID token received, length: \(idToken.count) characters", level: .debug, category: .authentication)
        
        // Create request to your backend
        var request = URLRequest(url: URL(string: "https://treblesurf.com/api/auth/google")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["id_token": idToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        logger.log("Sending request to backend: \(request.url?.absoluteString ?? "Invalid URL")", level: .debug, category: .network)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                logger.log("Received HTTP response: \(httpResponse.statusCode)", level: .debug, category: .authentication)
                
                // Extract CSRF token from response headers
                if let csrfToken = httpResponse.value(forHTTPHeaderField: "X-CSRF-Token") {
                    self.csrfToken = csrfToken
                    logger.log("CSRF token extracted from response header: \(csrfToken)", level: .debug, category: .authentication)
                }
                
                // Extract session ID from cookies
                if let cookies = httpResponse.allHeaderFields["Set-Cookie"] as? String {
                    self.extractSessionId(from: cookies)
                }
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            return (true, authResponse.user)
        } catch {
            logger.log("Request failed with error: \(error.localizedDescription)", level: .error, category: .authentication)
            return (false, nil)
        }
    }
    
    nonisolated private func extractSessionId(from cookieString: String) {
        logger.log("Extracting session ID from cookies: \(cookieString)", level: .debug, category: .authentication)
        
        // Parse Set-Cookie header to extract session_id
        // The cookie string might contain multiple cookies separated by commas
        let cookiePairs = cookieString.components(separatedBy: ",")
        
        for cookiePair in cookiePairs {
            let trimmed = cookiePair.trimmingCharacters(in: .whitespaces)
            
            // Look for session_id cookie
            if trimmed.hasPrefix("session_id=") {
                let sessionIdPart = String(trimmed.dropFirst("session_id=".count))
                // Remove any additional attributes after the value (like Path, Expires, etc.)
                let sessionId = sessionIdPart.components(separatedBy: ";").first ?? sessionIdPart
                self.sessionId = sessionId
                logger.log("Session ID extracted: \(sessionId)", level: .debug, category: .authentication)
                return
            }
        }
        
        // If we didn't find session_id, try to extract from the full string
        // Sometimes the cookie format can be different
        if cookieString.contains("session_id=") {
            let components = cookieString.components(separatedBy: ";")
            for component in components {
                let trimmed = component.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("session_id=") {
                    let sessionIdPart = String(trimmed.dropFirst("session_id=".count))
                    let sessionId = sessionIdPart.components(separatedBy: ";").first ?? sessionIdPart
                    self.sessionId = sessionId
                    logger.log("Session ID extracted (fallback): \(sessionId)", level: .debug, category: .authentication)
                    return
                }
            }
        }
        
        logger.log("Failed to extract session ID from cookies", level: .error, category: .authentication)
        logger.log("Cookie string format: \(cookieString)", level: .debug, category: .authentication)
    }
    
    func validateSession() async -> (Bool, User?) {
        logger.log("Starting session validation...", level: .debug, category: .authentication)
        logger.log("Device: \(UIDevice.current.isSimulator ? "Simulator" : "Physical Device")", level: .debug, category: .authentication)
        logger.log("Stored session ID: \(sessionId ?? "None")", level: .debug, category: .authentication)
        logger.log("Stored CSRF token: \(csrfToken != nil ? "Present" : "None")", level: .debug, category: .authentication)
        logger.log("Stored user: \(currentUser?.email ?? "None")", level: .debug, category: .authentication)
        
        #if DEBUG
        // Check if running on simulator vs device
        let baseURL = UIDevice.current.isSimulator ? "http://localhost:8080" : "https://treblesurf.com"
        #else
        let baseURL = "https://treblesurf.com"
        #endif
        
        logger.log("Using base URL: \(baseURL)", level: .debug, category: .network)
        
        // In development environment, check if we have local session data
        #if DEBUG
        if UIDevice.current.isSimulator {
            // Check if we have a valid session ID locally
            if let sessionId = sessionId, !sessionId.isEmpty {
                logger.log("Development mode: Using local session validation", level: .debug, category: .authentication)
                // Return the current user if available
                return (true, currentUser)
            } else {
                logger.log("Development mode: No local session available", level: .debug, category: .authentication)
                return (false, nil)
            }
        }
        #endif
        
        // Use the correct API endpoint for session validation
        guard let url = URL(string: "\(baseURL)/api/auth/validate") else {
            return (false, nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add session cookie if available
        if let sessionId = sessionId, !sessionId.isEmpty {
            request.addValue("session_id=\(sessionId)", forHTTPHeaderField: "Cookie")
            logger.log("Adding session cookie for validation: session_id=\(sessionId)", level: .debug, category: .network)
        } else {
            logger.log("No local session ID available, attempting validation without cookie", level: .debug, category: .network)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                // Check if we received HTML instead of JSON (indicates wrong endpoint)
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   contentType.contains("text/html") {
                    logger.log("Received HTML response instead of JSON - wrong endpoint or backend issue", level: .error, category: .authentication)
                    return (false, nil)
                }

                // Extract CSRF token from response headers
                if let csrfToken = httpResponse.value(forHTTPHeaderField: "X-CSRF-Token") {
                    self.csrfToken = csrfToken
                    logger.log("CSRF token extracted: \(csrfToken)", level: .debug, category: .authentication)
                }
                
                // Extract session ID from cookies if we don't have one locally
                if let cookies = httpResponse.allHeaderFields["Set-Cookie"] as? String,
                   (self.sessionId == nil || self.sessionId?.isEmpty == true) {
                    self.extractSessionId(from: cookies)
                }
                
                if httpResponse.statusCode != 200 {
                    // Session is invalid
                    logger.log("Session validation failed with status: \(httpResponse.statusCode)", level: .error, category: .authentication)
                    self.clearAllAppData()
                    return (false, nil)
                }
            }
            
            // Check if response is HTML (wrong endpoint)
            if let responseString = String(data: data, encoding: .utf8),
               responseString.contains("<!DOCTYPE html>") {
                logger.log("Received HTML response instead of JSON - wrong endpoint or backend issue", level: .error, category: .authentication)
                logger.log("Response data: \(responseString)", level: .debug, category: .authentication)
                return (false, nil)
            }
            
            let validateResponse = try JSONDecoder().decode(ValidateResponse.self, from: data)
            if validateResponse.valid {
                self.currentUser = validateResponse.user
                self.isAuthenticated = true
                logger.log("Session validation successful for user: \(validateResponse.user.email)", level: .debug, category: .authentication)
                return (true, validateResponse.user)
            } else {
                logger.log("Session validation returned invalid", level: .error, category: .authentication)
                self.clearAllAppData()
                return (false, nil)
            }
        } catch {
            logger.log("Validation request failed: \(error.localizedDescription)", level: .error, category: .authentication)
            
            // In development, if server is not available, use local validation
            #if DEBUG
            if UIDevice.current.isSimulator {
                if let nsError = error as NSError? {
                    if nsError.code == NSURLErrorCannotConnectToHost ||
                       nsError.code == NSURLErrorTimedOut {
                        logger.log("Development server not available, using local session validation", level: .debug, category: .authentication)
                        if let sessionId = self.sessionId, !sessionId.isEmpty {
                            return (true, self.currentUser)
                        }
                    }
                }
            }
            #endif
            
            return (false, nil)
        }
    }
    
    func logout() async -> Bool {
        #if DEBUG
        // Check if running on simulator vs device
        let baseURL = UIDevice.current.isSimulator ? "http://localhost:8080" : "https://treblesurf.com"
        #else
        let baseURL = "https://treblesurf.com"
        #endif
        
        // Use the correct API endpoint for logout
        guard let url = URL(string: "\(baseURL)/api/auth/logout") else {
            // Even if the server request fails, we should still clear local data
            self.clearAllAppData()
            return true
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add session cookie if available
        if let sessionId = sessionId {
            request.addValue("session_id=\(sessionId)", forHTTPHeaderField: "Cookie")
            logger.log("Adding session cookie for logout: session_id=\(sessionId)", level: .debug, category: .network)
        }
        
        // Add CSRF token if available
        if let csrfToken = csrfToken {
            request.addValue(csrfToken, forHTTPHeaderField: "X-CSRF-Token")
            logger.log("Adding CSRF token for logout: \(csrfToken)", level: .debug, category: .network)
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                logger.log("Logout HTTP response: \(httpResponse.statusCode)", level: .debug, category: .authentication)
                
                // Check if we received HTML instead of JSON (indicates wrong endpoint)
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   contentType.contains("text/html") {
                    logger.log("Received HTML response instead of JSON during logout - wrong endpoint or backend issue", level: .error, category: .authentication)
                }
            }
        } catch {
            logger.log("Logout request failed: \(error.localizedDescription)", level: .error, category: .authentication)
        }
        
        // Always clear local data regardless of server response
        self.clearAllAppData()
        return true
    }
    
    /// Comprehensive method to clear all app data, caches, and user preferences
    nonisolated func clearAllAppData() {
        // Clear authentication data on main actor
        Task { @MainActor in
            self.currentUser = nil
            self.isAuthenticated = false
        }
        
        // Clear tokens (nonisolated properties)
        self.csrfToken = nil
        self.sessionId = nil
        
        // Clear all UserDefaults
        self.clearAllUserDefaults()
        
        // Clear all @AppStorage values
        self.clearAllAppStorage()
        
        // Clear all caches
        self.clearAllCaches()
        
        // Reset all stores to initial state
        self.resetAllStores()
        
        // Sign out from Google
        self.signOutFromGoogle()
        
        logger.log("All app data cleared successfully", level: .info, category: .authentication)
    }
    
    /// Clear all UserDefaults values
    nonisolated private func clearAllUserDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        logger.log("All UserDefaults cleared", level: .info, category: .authentication)
    }
    
    /// Clear all @AppStorage values
    nonisolated private func clearAllAppStorage() {
        // Clear saved locations
        UserDefaults.standard.removeObject(forKey: "savedLocations")
        
        // Clear any other @AppStorage keys you might have
        // Add more keys here as needed
        
        UserDefaults.standard.synchronize()
        logger.log("All @AppStorage values cleared", level: .info, category: .authentication)
    }
    
    /// Clear all caches
    nonisolated private func clearAllCaches() {
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear image cache if you have any
        // ImageCache.shared.clearAll() // Uncomment if you have an image cache
        
        logger.log("All caches cleared", level: .info, category: .authentication)
    }
    
    /// Reset all stores to initial state
    nonisolated private func resetAllStores() {
        // Reset DataStore
        Task { @MainActor in
            dataStore?.resetToInitialState()
            locationStore?.resetToInitialState()
            settingsStore?.resetToInitialState()
        }
        
        logger.log("All stores reset to initial state", level: .info, category: .authentication)
    }
    
    /// Sign out from Google
    nonisolated private func signOutFromGoogle() {
        GIDSignIn.sharedInstance.signOut()
        logger.log("Signed out from Google", level: .info, category: .authentication)
    }
    
    // MARK: - Development Mode Support
    
    func createDevSession(email: String) async -> Bool {
        // For development/testing purposes, create a session via backend
        #if DEBUG
        // Check if running on simulator vs device
        let baseURL = UIDevice.current.isSimulator ? "http://localhost:8080" : "https://treblesurf.com"
        #else
        let baseURL = "https://treblesurf.com"
        #endif
        
        // Use the correct API endpoint for development session creation
        guard let url = URL(string: "\(baseURL)/api/auth/dev-session") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let body = ["email": email]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                logger.log("Dev session HTTP response: \(httpResponse.statusCode)", level: .debug, category: .authentication)
                logger.log("Dev session response headers: \(httpResponse.allHeaderFields)", level: .debug, category: .authentication)
                
                // Check if we received HTML instead of JSON (indicates wrong endpoint)
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   contentType.contains("text/html") {
                    logger.log("Received HTML response instead of JSON during dev session creation - wrong endpoint or backend issue", level: .error, category: .authentication)
                    return false
                }
                
                // Extract CSRF token from response headers
                if let csrfToken = httpResponse.value(forHTTPHeaderField: "X-CSRF-Token") {
                    self.csrfToken = csrfToken
                    logger.log("CSRF token extracted: \(csrfToken)", level: .debug, category: .authentication)
                }

                // Extract session ID from cookies
                if let cookies = httpResponse.allHeaderFields["Set-Cookie"] as? String {
                    self.extractSessionId(from: cookies)
                } else {
                    logger.log("No Set-Cookie header found in response", level: .debug, category: .authentication)
                    logger.log("Available headers: \(httpResponse.allHeaderFields.keys)", level: .debug, category: .authentication)
                }

                if httpResponse.statusCode == 200 {
                    // Create a mock user for development
                    let devUser = User(
                        email: email,
                        name: "Development User",
                        picture: "https://via.placeholder.com/150",
                        familyName: "User",
                        givenName: "Development",
                        createdAt: nil, // Optional field
                        lastLogin: nil, // Optional field
                        theme: "dark"
                    )

                    self.currentUser = devUser
                    self.isAuthenticated = true
                    logger.log("Development session created successfully for: \(email)", level: .debug, category: .authentication)
                    return true
                } else {
                    logger.log("Dev session creation failed with status: \(httpResponse.statusCode)", level: .error, category: .authentication)
                    return false
                }
            } else {
                logger.log("No HTTP response received", level: .error, category: .authentication)
                return false
            }
        } catch {
            logger.log("Dev session creation failed: \(error.localizedDescription)", level: .error, category: .authentication)
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    func getAuthHeader() -> [String: String]? {
        // For session-based auth, we don't need Authorization header
        // The session cookie will be automatically sent
        return nil
    }
    
    nonisolated func getCsrfHeader() -> [String: String]? {
        guard let csrf = csrfToken else { return nil }
        return ["X-CSRF-Token": csrf]
    }
    
    nonisolated func getSessionCookie() -> [String: String]? {
        guard let sessionId = sessionId else { return nil }
        return ["Cookie": "session_id=\(sessionId)"]
    }

    nonisolated func updateCsrfToken(_ token: String) {
        csrfToken = token
    }
    
    // Check if running in simulator
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // Debug method to print current authentication state
    func printAuthState() {
        logger.log("=== Authentication State ===", level: .debug, category: .authentication)
        logger.log("Is Simulator: \(isSimulator)", level: .debug, category: .authentication)
        logger.log("Has Session ID: \(sessionId != nil)", level: .debug, category: .authentication)
        logger.log("Has CSRF Token: \(csrfToken != nil)", level: .debug, category: .authentication)
        logger.log("Is Authenticated: \(isAuthenticated)", level: .debug, category: .authentication)
        logger.log("Current User: \(currentUser?.email ?? "None")", level: .debug, category: .authentication)
        logger.log("==========================", level: .debug, category: .authentication)
    }
    

}
