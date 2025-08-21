//
//  AuthManager.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import GoogleSignIn
import SwiftUI
import UIKit

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    
    private let csrfKey = "com.treblesurf.csrfToken"
    private let sessionKey = "com.treblesurf.sessionId"
    
    var csrfToken: String? {
        get {
            return KeychainHelper.shared.retrieve(key: csrfKey)
        }
        set {
            if let token = newValue {
                KeychainHelper.shared.save(key: csrfKey, value: token)
            } else {
                KeychainHelper.shared.delete(key: csrfKey)
            }
        }
    }
    
    var sessionId: String? {
        get {
            return KeychainHelper.shared.retrieve(key: sessionKey)
        }
        set {
            if let token = newValue {
                KeychainHelper.shared.save(key: sessionKey, value: token)
            } else {
                KeychainHelper.shared.delete(key: sessionKey)
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
    
    // MARK: - Authentication Methods
    
    func authenticateWithBackend(user: GIDGoogleUser, completion: @escaping (Bool, User?) -> Void) {
        guard let idToken = user.idToken?.tokenString else {
            completion(false, nil)
            return
        }
        
        // Create request to your backend
        var request = URLRequest(url: URL(string: "https://treblesurf.com/api/auth/google")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["id_token": idToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        print("Sending request to backend: \(request)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Request failed with error: \(error.localizedDescription)")
                completion(false, nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Received HTTP response: \(httpResponse.statusCode)")
                
                // Extract CSRF token from response headers
                if let csrfToken = httpResponse.value(forHTTPHeaderField: "X-CSRF-Token") {
                    self.csrfToken = csrfToken
                    print("CSRF token extracted from response header: \(csrfToken)")
                }
                
                // Extract session ID from cookies
                if let cookies = httpResponse.allHeaderFields["Set-Cookie"] as? String {
                    self.extractSessionId(from: cookies)
                }
            }
            
            guard let data = data else {
                print("No data received")
                completion(false, nil)
                return
            }
            
            do {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                DispatchQueue.main.async {
                    self.currentUser = authResponse.user
                    self.isAuthenticated = true
                }
                completion(true, authResponse.user)
            } catch {
                print("Failed to decode response: \(error)")
                completion(false, nil)
            }
        }.resume()
    }
    
    private func extractSessionId(from cookieString: String) {
        print("Extracting session ID from cookies: \(cookieString)")
        
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
                print("Session ID extracted: \(sessionId)")
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
                    print("Session ID extracted (fallback): \(sessionId)")
                    return
                }
            }
        }
        
        print("Failed to extract session ID from cookies")
        print("Cookie string format: \(cookieString)")
    }
    
    func validateSession(completion: @escaping (Bool, User?) -> Void) {
        #if DEBUG
        // Check if running on simulator vs device
        let baseURL = UIDevice.current.isSimulator ? "http://localhost:8080" : "https://treblesurf.com"
        #else
        let baseURL = "https://treblesurf.com"
        #endif
        
        // In development environment, check if we have local session data
        #if DEBUG
        if UIDevice.current.isSimulator {
            // Check if we have a valid session ID locally
            if let sessionId = sessionId, !sessionId.isEmpty {
                print("Development mode: Using local session validation")
                // Return the current user if available
                completion(true, currentUser)
                return
            } else {
                print("Development mode: No local session available")
                completion(false, nil)
                return
            }
        }
        #endif
        
        // Use the correct API endpoint for session validation
        guard let url = URL(string: "\(baseURL)/api/auth/validate") else {
            completion(false, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add session cookie if available
        if let sessionId = sessionId {
            request.addValue("session_id=\(sessionId)", forHTTPHeaderField: "Cookie")
        } else {
            print("No session ID available for validation")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Validation request failed: \(error.localizedDescription)")
                
                // In development, if server is not available, use local validation
                #if DEBUG
                if UIDevice.current.isSimulator {
                                    if let nsError = error as NSError? {
                    if nsError.code == NSURLErrorCannotConnectToHost || 
                       nsError.code == NSURLErrorTimedOut {
                        print("Development server not available, using local session validation")
                        if let sessionId = self.sessionId, !sessionId.isEmpty {
                            completion(true, self.currentUser)
                            return
                        }
                    }
                }
                }
                #endif
                
                completion(false, nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                // Check if we received HTML instead of JSON (indicates wrong endpoint)
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   contentType.contains("text/html") {
                    print("Received HTML response instead of JSON - wrong endpoint or backend issue")
                    completion(false, nil)
                    return
                }
                
                // Extract CSRF token from response headers
                if let csrfToken = httpResponse.value(forHTTPHeaderField: "X-CSRF-Token") {
                    self.csrfToken = csrfToken
                    print("CSRF token extracted: \(csrfToken)")
                }
                
                if httpResponse.statusCode != 200 {
                    // Session is invalid
                    print("Session validation failed with status: \(httpResponse.statusCode)")
                    self.clearAllAppData()
                    completion(false, nil)
                    return
                }
            }
            
            guard let data = data else {
                completion(false, nil)
                return
            }
            
            // Check if response is HTML (wrong endpoint)
            if let responseString = String(data: data, encoding: .utf8),
               responseString.contains("<!DOCTYPE html>") {
                print("Received HTML response instead of JSON - wrong endpoint or backend issue")
                print("Response data: \(responseString)")
                completion(false, nil)
                return
            }
            
            do {
                let validateResponse = try JSONDecoder().decode(ValidateResponse.self, from: data)
                if validateResponse.valid {
                    DispatchQueue.main.async {
                        self.currentUser = validateResponse.user
                        self.isAuthenticated = true
                    }
                    print("Session validation successful for user: \(validateResponse.user.email)")
                    completion(true, validateResponse.user)
                } else {
                    print("Session validation returned invalid")
                    DispatchQueue.main.async {
                        self.clearAllAppData()
                    }
                    completion(false, nil)
                }
            } catch {
                print("Failed to decode validation response: \(error)")
                print("Response data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
                completion(false, nil)
            }
        }.resume()
    }
    
    func logout(completion: @escaping (Bool) -> Void) {
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
            completion(true)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add session cookie if available
        if let sessionId = sessionId {
            request.addValue("session_id=\(sessionId)", forHTTPHeaderField: "Cookie")
            print("Adding session cookie for logout: session_id=\(sessionId)")
        }
        
        // Add CSRF token if available
        if let csrfToken = csrfToken {
            request.addValue(csrfToken, forHTTPHeaderField: "X-CSRF-Token")
            print("Adding CSRF token for logout: \(csrfToken)")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Logout request failed: \(error.localizedDescription)")
                    // Even if server logout fails, clear local data
                    self.clearAllAppData()
                    completion(true)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Logout HTTP response: \(httpResponse.statusCode)")
                    
                    // Check if we received HTML instead of JSON (indicates wrong endpoint)
                    if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                       contentType.contains("text/html") {
                        print("Received HTML response instead of JSON during logout - wrong endpoint or backend issue")
                    }
                }
                
                // Always clear local data regardless of server response
                self.clearAllAppData()
                completion(true)
            }
        }.resume()
    }
    
    /// Comprehensive method to clear all app data, caches, and user preferences
    private func clearAllAppData() {
        DispatchQueue.main.async {
            // Clear authentication data
            self.currentUser = nil
            self.isAuthenticated = false
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
            
            print("All app data cleared successfully")
        }
    }
    
    /// Clear all UserDefaults values
    private func clearAllUserDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        print("All UserDefaults cleared")
    }
    
    /// Clear all @AppStorage values
    private func clearAllAppStorage() {
        // Clear saved locations
        UserDefaults.standard.removeObject(forKey: "savedLocations")
        
        // Clear any other @AppStorage keys you might have
        // Add more keys here as needed
        
        UserDefaults.standard.synchronize()
        print("All @AppStorage values cleared")
    }
    
    /// Clear all caches
    private func clearAllCaches() {
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear image cache if you have any
        // ImageCache.shared.clearAll() // Uncomment if you have an image cache
        
        print("All caches cleared")
    }
    
    /// Reset all stores to initial state
    private func resetAllStores() {
        // Reset DataStore
        DataStore.shared.resetToInitialState()
        
        // Reset LocationStore
        LocationStore.shared.resetToInitialState()
        
        // Reset SettingsStore
        SettingsStore.shared.resetToInitialState()
        
        print("All stores reset to initial state")
    }
    
    /// Sign out from Google
    private func signOutFromGoogle() {
        GIDSignIn.sharedInstance.signOut()
        print("Signed out from Google")
    }
    
    // MARK: - Development Mode Support
    
    func createDevSession(email: String, completion: @escaping (Bool) -> Void) {
        // For development/testing purposes, create a session via backend
        #if DEBUG
        // Check if running on simulator vs device
        let baseURL = UIDevice.current.isSimulator ? "http://localhost:8080" : "https://treblesurf.com"
        #else
        let baseURL = "https://treblesurf.com"
        #endif
        
        // Use the correct API endpoint for development session creation
        guard let url = URL(string: "\(baseURL)/api/auth/dev-session") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let body = ["email": email]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Dev session creation failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Dev session HTTP response: \(httpResponse.statusCode)")
                    print("Dev session response headers: \(httpResponse.allHeaderFields)")
                    
                    // Check if we received HTML instead of JSON (indicates wrong endpoint)
                    if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                       contentType.contains("text/html") {
                        print("Received HTML response instead of JSON during dev session creation - wrong endpoint or backend issue")
                        completion(false)
                        return
                    }
                    
                    // Extract CSRF token from response headers
                    if let csrfToken = httpResponse.value(forHTTPHeaderField: "X-CSRF-Token") {
                        self.csrfToken = csrfToken
                        print("CSRF token extracted: \(csrfToken)")
                    }
                    
                    // Extract session ID from cookies
                    if let cookies = httpResponse.allHeaderFields["Set-Cookie"] as? String {
                        self.extractSessionId(from: cookies)
                    } else {
                        print("No Set-Cookie header found in response")
                        print("Available headers: \(httpResponse.allHeaderFields.keys)")
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
                        
                        DispatchQueue.main.async {
                            self.currentUser = devUser
                            self.isAuthenticated = true
                        }
                        print("Development session created successfully for: \(email)")
                        completion(true)
                    } else {
                        print("Dev session creation failed with status: \(httpResponse.statusCode)")
                        completion(false)
                    }
                } else {
                    print("No HTTP response received")
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    func getAuthHeader() -> [String: String]? {
        // For session-based auth, we don't need Authorization header
        // The session cookie will be automatically sent
        return nil
    }
    
    func getCsrfHeader() -> [String: String]? {
        guard let csrf = csrfToken else { return nil }
        return ["X-CSRF-Token": csrf]
    }
    
    func getSessionCookie() -> [String: String]? {
        guard let sessionId = sessionId else { return nil }
        return ["Cookie": "session_id=\(sessionId)"]
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
        print("=== Authentication State ===")
        print("Is Simulator: \(isSimulator)")
        print("Has Session ID: \(sessionId != nil)")
        print("Has CSRF Token: \(csrfToken != nil)")
        print("Is Authenticated: \(isAuthenticated)")
        print("Current User: \(currentUser?.email ?? "None")")
        print("==========================")
    }
    

}
