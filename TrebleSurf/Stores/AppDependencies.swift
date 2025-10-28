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
class AppDependencies {
    nonisolated static let shared = AppDependencies()
    
    // MARK: - Error Handling Infrastructure
    
    lazy var errorLogger: ErrorLoggerProtocol = {
        #if DEBUG
        return ErrorLogger(minimumLogLevel: .debug, enableConsoleOutput: true, enableOSLog: true)
        #else
        return ErrorLogger(minimumLogLevel: .info, enableConsoleOutput: false, enableOSLog: true)
        #endif
    }()
    
    lazy var errorHandler: ErrorHandlerProtocol = ErrorHandler(logger: errorLogger)
    
    // MARK: - Lazy Dependencies
    
    lazy var dataStore: any DataStoreProtocol = DataStore.shared
    lazy var authManager: any AuthManagerProtocol = AuthManager.shared
    lazy var apiClient: any APIClientProtocol = APIClient.shared
    lazy var settingsStore: any SettingsStoreProtocol = SettingsStore.shared
    lazy var locationStore: any LocationStoreProtocol = LocationStore.shared
    lazy var imageCache: any ImageCacheProtocol = ImageCacheService.shared
    lazy var config: any AppConfigurationProtocol = AppConfiguration.shared
    lazy var buoyCacheService = BuoyCacheService.shared
    
    // MARK: - Initialization
    
    nonisolated private init() {}
    
    // MARK: - Testing Support
    
    /// Create a mock dependencies instance for testing
    nonisolated static func createMock() -> AppDependencies {
        let deps = AppDependencies()
        // In the future, can swap implementations here
        // deps.dataStore = MockDataStore()
        // deps.authManager = MockAuthManager()
        return deps
    }
    
    // MARK: - Reset
    
    /// Reset all dependencies to clean state
    func reset() {
        dataStore.resetToInitialState()
        settingsStore.resetToInitialState()
        locationStore.resetToInitialState()
    }
}

