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
    
    func fetchConditions(for spotId: String, completion: @escaping (Bool) -> Void)
    func fetchForecast(for spotId: String, completion: @escaping (Bool) -> Void)
    func fetchRegionSpots(region: String, completion: @escaping (Result<[SpotData], Error>) -> Void)
    func fetchSpotImage(for spotId: String, completion: @escaping (Image?) -> Void)
    
    func clearSpotCache(for spotId: String?)
    func clearRegionSpotsCache(for region: String?)
    func refreshSpotData(for spotId: String)
    func refreshRegionData(for region: String)
    func resetToInitialState()
}

// MARK: - APIClient Protocol

protocol APIClientProtocol {
    func fetchSpots(country: String, region: String, completion: @escaping (Result<[SpotData], Error>) -> Void)
    func fetchDonegalSpots(completion: @escaping (Result<[SpotData], Error>) -> Void)
    func fetchCurrentConditions(country: String, region: String, spot: String, completion: @escaping (Result<[CurrentConditionsResponse], Error>) -> Void)
    func fetchForecast(country: String, region: String, spot: String, completion: @escaping (Result<[ForecastResponse], Error>) -> Void)
    func fetchBuoys(region: String, completion: @escaping (Result<[BuoyLocation], Error>) -> Void)
    func fetchBuoyData(buoyNames: [String], completion: @escaping (Result<[BuoyResponse], Error>) -> Void)
    func fetchLast24HoursBuoyData(buoyName: String, completion: @escaping (Result<[BuoyResponse], Error>) -> Void)
    func fetchSurfReports(country: String, region: String, spot: String, completion: @escaping (Result<[SurfReportResponse], Error>) -> Void)
    func fetchLocationInfo(country: String, region: String, spot: String, completion: @escaping (Result<SpotData, Error>) -> Void)
    func getReportImage(key: String, completion: @escaping (Result<SurfReportImageResponse, Error>) -> Void)
    func getReportVideo(key: String, completion: @escaping (Result<SurfReportVideoResponse, Error>) -> Void)
    func getVideoViewURL(key: String, completion: @escaping (Result<PresignedVideoViewResponse, Error>) -> Void)
}

// MARK: - AuthManager Protocol

@MainActor
protocol AuthManagerProtocol: ObservableObject {
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }
    
    func validateSession(completion: @escaping (Bool, User?) -> Void)
    func logout(completion: @escaping (Bool) -> Void)
    nonisolated func hasStoredAuthData() -> Bool
    func authenticateWithBackend(user: GIDGoogleUser, completion: @escaping (Bool, User?) -> Void)
}

// MARK: - ImageCacheProtocol

protocol ImageCacheProtocol {
    func getCachedSpotImage(for spotId: String, completion: @escaping (Image?) -> Void)
    func getCachedSurfReportImage(for imageKey: String, completion: @escaping (Image?) -> Void)
    func getCachedSurfReportImageData(for imageKey: String, completion: @escaping (Data?) -> Void)
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

