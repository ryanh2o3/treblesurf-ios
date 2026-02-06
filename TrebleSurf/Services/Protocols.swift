//
//  Protocols.swift
//  TrebleSurf
//
//  Created by Ryan Patton
//

import Foundation
import SwiftUI
import GoogleSignIn
import CoreLocation

// MARK: - DataStore Protocol

@MainActor
protocol DataStoreProtocol: ObservableObject {
    var currentConditions: ConditionData { get }
    var currentConditionsTimestamp: String { get }
    var currentForecastEntries: [ForecastEntry] { get }
    var currentSpotId: String { get set }
    var regionSpots: [SpotData] { get }
    
    func fetchConditions(for spotId: String) async -> Bool
    func fetchForecast(for spotId: String) async -> Bool
    func fetchRegionSpots(region: String) async throws -> [SpotData]
    func fetchSpotImage(for spotId: String) async -> Image?
    
    func clearSpotCache(for spotId: String?)
    func clearRegionSpotsCache(for region: String?)
    func refreshSpotData(for spotId: String)
    func refreshRegionData(for region: String)
    func resetToInitialState()
}

// MARK: - SpotService Protocol

protocol SpotServiceProtocol {
    func fetchSpots(country: String, region: String) async throws -> [SpotData]
    func fetchDonegalSpots() async throws -> [SpotData]
    func fetchLocationInfo(country: String, region: String, spot: String) async throws -> SpotData
}

// MARK: - APIClient Protocol

protocol APIClientProtocol {
    func fetchCurrentConditions(country: String, region: String, spot: String) async throws -> [CurrentConditionsResponse]
    func fetchForecast(country: String, region: String, spot: String) async throws -> [ForecastResponse]
    func fetchBuoys(region: String) async throws -> [BuoyLocation]
    func fetchBuoyData(buoyNames: [String]) async throws -> [BuoyResponse]
    func fetchLast24HoursBuoyData(buoyName: String) async throws -> [BuoyResponse]
    func fetchBuoyDataRange(buoyName: String, startDate: Date, endDate: Date) async throws -> [BuoyResponse]
    // Surf Reports Protocol methods moved to SurfReportServiceProtocol - removing from here in next steps or keeping for backward compat during migration?
    // Plan said: remove spot related methods. Keeping others for now.
    
    // Generic Request support
    func request<T: Decodable>(_ endpoint: String, method: String, body: Data?) async throws -> T
    func postRequest<T: Decodable>(to endpoint: String, body: Data) async throws -> T
    
    // Surf Reports
    func fetchSurfReportsWithMatchingConditions(
        country: String,
        region: String,
        spot: String,
        daysBack: Int,
        maxResults: Int
    ) async throws -> [SurfReportResponse]
    
    
    func fetchSurfReportsWithSimilarBuoyData(
        waveHeight: Double,
        waveDirection: Double,
        period: Double,
        buoyName: String,
        maxResults: Int
    ) async throws -> [SurfReportResponse]
    
    func refreshCSRFToken() async -> Bool
    func makeFlexibleRequest<T: Decodable>(to endpoint: String, method: String, requiresAuth: Bool, body: Data?) async throws -> T
}

// MARK: - APIClientProtocol Default Implementations
extension APIClientProtocol {
    func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        return try await request(endpoint, method: method, body: body)
    }
    
    func makeFlexibleRequest<T: Decodable>(to endpoint: String, method: String = "GET", requiresAuth: Bool = true, body: Data? = nil) async throws -> T {
        return try await makeFlexibleRequest(to: endpoint, method: method, requiresAuth: requiresAuth, body: body)
    }
    
    func fetchSurfReportsWithMatchingConditions(
        country: String,
        region: String,
        spot: String,
        daysBack: Int = 365,
        maxResults: Int = 20
    ) async throws -> [SurfReportResponse] {
        return try await fetchSurfReportsWithMatchingConditions(
            country: country,
            region: region,
            spot: spot,
            daysBack: daysBack,
            maxResults: maxResults
        )
    }
    
    }



// MARK: - AuthManager Protocol

@MainActor
protocol AuthManagerProtocol: ObservableObject {
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }

    func validateSession() async -> (Bool, User?)
    func logout() async -> Bool
    nonisolated func hasStoredAuthData() -> Bool
    func authenticateWithBackend(user: GIDGoogleUser) async -> (Bool, User?)
    nonisolated func getSessionCookie() -> [String: String]?
    nonisolated func getCsrfHeader() -> [String: String]?
    nonisolated func clearAllAppData()
    nonisolated func updateCsrfToken(_ token: String)
}

// MARK: - ImageCacheProtocol

protocol ImageCacheProtocol {
    func getCachedSpotImage(for spotId: String) async -> Image?
    func getCachedSurfReportImage(for imageKey: String) async -> Image?
    func getCachedSurfReportImageData(for imageKey: String) async -> Data?
    func cacheSpotImage(_ imageData: Data, for spotId: String)
    func cacheSurfReportImage(_ imageData: Data, for imageKey: String)
    func removeCachedSpotImage(for spotId: String)
    func removeCachedSurfReportImage(for imageKey: String)
    func clearAllCache()
}

// MARK: - SettingsStore Protocol

@MainActor
protocol SettingsStoreProtocol: ObservableObject {
    var selectedTheme: ThemeMode { get set }
    var isDarkMode: Bool { get }
    var showSwellPredictions: Bool { get set }
    
    func getPreferredColorScheme() -> ColorScheme?
    func resetToInitialState()
}

// MARK: - LocationStore Protocol

@MainActor
protocol LocationStoreProtocol: ObservableObject {
    var country: String { get }
    var region: String { get }
    var spot: String { get }
    var coordinates: CLLocationCoordinate2D? { get }
    var isLocationServiceEnabled: Bool { get }
    var savedLocations: [LocationData] { get }
    
    func setCurrentLocation(country: String, region: String, spot: String, coordinates: CLLocationCoordinate2D?)
    func getCurrentLocationData() -> LocationData?
    func saveLocation(_ location: LocationData)
    func removeLocation(at indexSet: IndexSet)
    func removeLocation(_ location: LocationData)
    func resetToInitialState()
}

