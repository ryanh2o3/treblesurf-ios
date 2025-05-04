//
//  ApiClient.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import Foundation

class APIClient {
    static let shared = APIClient()

    func request<T: Decodable>(_ endpoint: String, method: String = "GET", completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "https://treblesurf.com\(endpoint)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method

        // Add authentication header
        if let headers = AuthManager.shared.getAuthHeader() {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let noDataError = NSError(domain: "APIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                completion(.failure(noDataError))
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func makeAuthenticatedRequest<T: Decodable>(to endpoint: String, completion: @escaping (Result<T, Error>) -> Void) {
        AuthManager.shared.refreshTokenIfNeeded { success in
            guard success else {
                let error = NSError(domain: "APIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Token refresh failed"])
                print("Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let authHeader = AuthManager.shared.getAuthHeader() else {
                let error = NSError(domain: "APIClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Auth header is missing"])
                print("Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let csrfHeader = AuthManager.shared.getCsrfHeader() else {
                let error = NSError(domain: "APIClient", code: 3, userInfo: [NSLocalizedDescriptionKey: "CSRF header is missing"])
                print("Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let url = URL(string: "https://treblesurf.com\(endpoint)") else {
                let error = NSError(domain: "APIClient", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                print("Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.allHTTPHeaderFields = authHeader.merging(csrfHeader) { (_, new) in new }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    let noDataError = NSError(domain: "APIClient", code: 5, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    print("Error: \(noDataError.localizedDescription)")
                    completion(.failure(noDataError))
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    print("Decoding error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }.resume()
        }
    }
}
