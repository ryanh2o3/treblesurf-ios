//
//  AppDependencies.swift
//  TrebleSurf
//
//  Created by Ryan Patton
//

import Foundation
import SwiftUI

/// Centralized dependency container for the app
@MainActor
final class AppDependencies: ObservableObject {
    // MARK: - Core Dependencies
    
    let config: AppConfigurationProtocol
    let errorLogger: ErrorLoggerProtocol
    let errorHandler: ErrorHandlerProtocol
    
    // MARK: - Stores & Services
    
    let authManager: AuthManager
    let settingsStore: SettingsStore
    let locationStore: LocationStore
    let imageCache: ImageCacheService
    let buoyCacheService: BuoyCacheService
    let imageValidationService: ImageValidationService
    let apiClient: APIClient
    let dataStore: DataStore
    let surfReportService: SurfReportService
    let weatherBuoyService: WeatherBuoyService
    let swellPredictionService: SwellPredictionService
    let spotService: SpotService
    let mediaProcessingService: MediaProcessingService
    let mediaUploadService: MediaUploadService
    let contentModerationService: ContentModerationService

    // MARK: - Initialization
    
    init() {
        let config = AppConfiguration()
        let errorLogger: ErrorLoggerProtocol = {
            #if DEBUG
            return ErrorLogger(minimumLogLevel: .debug, enableConsoleOutput: true, enableOSLog: true)
            #else
            return ErrorLogger(minimumLogLevel: .info, enableConsoleOutput: false, enableOSLog: true)
            #endif
        }()
        
        self.config = config
        self.errorLogger = errorLogger
        self.errorHandler = ErrorHandler(logger: errorLogger)
        
        let keychain = KeychainHelper()
        let authManager = AuthManager(keychain: keychain, logger: errorLogger)
        let settingsStore = SettingsStore()
        let locationStore = LocationStore()
        let imageCache = ImageCacheService(logger: errorLogger)
        let buoyCacheService = BuoyCacheService()
        let imageValidationService = ImageValidationService()
        let apiClient = APIClient(config: config, authManager: authManager)
        let spotService = SpotService(apiClient: apiClient)
        let dataStore = DataStore(config: config, apiClient: apiClient, imageCache: imageCache, spotService: spotService, logger: errorLogger)
        
        authManager.setStores(
            dataStore: dataStore,
            locationStore: locationStore,
            settingsStore: settingsStore
        )
        
        self.authManager = authManager
        self.settingsStore = settingsStore
        self.locationStore = locationStore
        self.imageCache = imageCache
        self.buoyCacheService = buoyCacheService
        self.imageValidationService = imageValidationService
        self.apiClient = apiClient
        self.spotService = spotService
        self.dataStore = dataStore
        self.surfReportService = SurfReportService(apiClient: apiClient, imageCacheService: imageCache, spotService: spotService, logger: errorLogger)
        self.weatherBuoyService = WeatherBuoyService(apiClient: apiClient, buoyCacheService: buoyCacheService, logger: errorLogger)
        self.swellPredictionService = SwellPredictionService(apiClient: apiClient)

        let mediaProcessingService = MediaProcessingService(logger: errorLogger)
        self.mediaProcessingService = mediaProcessingService
        self.mediaUploadService = MediaUploadService(apiClient: apiClient, mediaProcessingService: mediaProcessingService, logger: errorLogger)
        self.contentModerationService = ContentModerationService(apiClient: apiClient, logger: errorLogger)
    }
    
    // MARK: - Testing Support
    
    /// Create a mock dependencies instance for testing
    static func createMock() -> AppDependencies {
        // In the future, can swap implementations here
        return AppDependencies()
    }
    
    // MARK: - Reset
    
    /// Reset all dependencies to clean state
    func reset() {
        dataStore.resetToInitialState()
        settingsStore.resetToInitialState()
        locationStore.resetToInitialState()
    }
}

