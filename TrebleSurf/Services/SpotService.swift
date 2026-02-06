//
//  SpotService.swift
//  TrebleSurf
//
//  Created by Ryan Patton
//

import Foundation

class SpotService: SpotServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    func fetchSpots(country: String, region: String) async throws -> [SpotData] {
        let endpoint = "/api/spots?country=\(country)&region=\(region)"
        return try await apiClient.request(endpoint, method: "GET", body: nil)
    }
    
    // Convenience method for the specific Donegal, Ireland endpoint
    func fetchDonegalSpots() async throws -> [SpotData] {
        return try await fetchSpots(country: "Ireland", region: "Donegal")
    }
    
    func fetchLocationInfo(country: String, region: String, spot: String) async throws -> SpotData {
        let endpoint = "/api/locationInfo?country=\(country)&region=\(region)&spot=\(spot)"
        return try await apiClient.request(endpoint, method: "GET", body: nil)
    }
}
