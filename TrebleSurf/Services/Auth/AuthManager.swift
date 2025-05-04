//
//  AuthManager.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import GoogleSignIn
import SwiftUI

class AuthManager {
    static let shared = AuthManager()
    private var currentUser: GIDGoogleUser?
    private let jwtKey = "com.treblesurf.jwtToken"
        private let csrfKey = "com.treblesurf.csrfToken"

        var jwtToken: String? {
            get {
                return KeychainHelper.shared.retrieve(key: jwtKey)
            }
            set {
                if let token = newValue {
                    KeychainHelper.shared.save(key: jwtKey, value: token)
                } else {
                    KeychainHelper.shared.delete(key: jwtKey)
                }
            }
        }

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

    var csrfTokenValue: String? {
            get {
                return csrfToken
            }
            set {
                csrfToken = newValue
            }
        }
    
    func authenticateWithBackend(user: GIDGoogleUser, completion: @escaping (Bool, Data?) -> Void) {
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
                    }
                    
                    if let data = data {
                        print("Received response data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
                    }
                    
                    guard let data = data else {
                        print("No data received")
                        completion(false, nil)
                        return
                    }
                    
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["token"] as? String {
                    self.jwtToken = token
                    completion(true, data)
                } else {
                    completion(false, nil)
                }
            } catch {
                completion(false, nil)
            }
        }.resume()
    }
    
    private func decodeJWTExpiration(from token: String) -> TimeInterval? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            print("Error: JWT token does not have the expected 3 parts. Token: \(token)")
            return nil
        }

        var payloadPart = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding to make the length a multiple of 4
        while payloadPart.count % 4 != 0 {
            payloadPart.append("=")
        }

        guard let payloadData = Data(base64Encoded: payloadPart, options: .ignoreUnknownCharacters) else {
            print("Error: Failed to decode base64 payload. Payload part: \(payloadPart)")
            return nil
        }

        do {
            if let payload = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                print("Decoded JWT payload: \(payload)")
                if let exp = payload["exp"] as? TimeInterval {
                    return exp
                } else {
                    print("Error: 'exp' field not found in payload.")
                }
            } else {
                print("Error: Payload is not a valid JSON object.")
            }
        } catch {
            print("Error: Failed to parse JWT payload: \(error.localizedDescription)")
        }

        return nil
    }

    func refreshTokenIfNeeded(completion: @escaping (Bool) -> Void) {
        guard let token = jwtToken else {
            print("Error: No JWT token available for refresh.")
            completion(false)
            return
        }

        guard let exp = decodeJWTExpiration(from: token) else {
            print("Error: Failed to decode JWT expiration.")
            completion(false)
            return
        }

        let expirationDate = Date(timeIntervalSince1970: exp)
        print("Token expiration date: \(expirationDate)")

        if expirationDate.timeIntervalSinceNow < 24 * 60 * 60 { // Less than 24 hours
            print("Token is close to expiration. Attempting to refresh...")

            var request = URLRequest(url: URL(string: "https://treblesurf.com/api/auth/validate")!)
            request.httpMethod = "GET"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error during token refresh request: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("Token refresh HTTP response status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("Error: Unexpected HTTP status code during token refresh.")
                        completion(false)
                        return
                    }
                }

                guard let data = data else {
                    print("Error: No data received during token refresh.")
                    completion(false)
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let newToken = json["token"] as? String,
                       let newCsrfToken = json["csrf_token"] as? String {
                        self.jwtToken = newToken
                        self.csrfToken = newCsrfToken
                        print("Token refresh successful. New token and CSRF token set.")
                        completion(true)
                    } else {
                        print("Error: Unexpected response format during token refresh. Response: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
                        completion(false)
                    }
                } catch {
                    print("Error: Failed to parse token refresh response: \(error.localizedDescription)")
                    completion(false)
                }
            }.resume()
        } else {
            print("Token is still valid. No refresh needed.")
            completion(true)
        }
    }
    
    func getAuthHeader() -> [String: String]? {
        guard let token = jwtToken else { return nil }
        return ["Authorization": "Bearer \(token)"]
    }
    
    func getCsrfHeader() -> [String: String]? {
            guard let csrf = csrfToken else { return nil }
            return ["X-CSRF-Token": csrf]
        }
    
}
