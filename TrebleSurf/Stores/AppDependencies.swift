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
    static let shared = AppDependencies()
    
    // MARK: - Lazy Dependencies
    
    lazy var dataStore: DataStoreProtocol = DataStore.shared
    lazy var authManager: AuthManagerProtocol = AuthManager.shared
    lazy var apiClient: APIClientProtocol = APIClient.shared
    lazy var settingsStore: SettingsStoreProtocol = SettingsStore.shared
    lazy var locationStore: LocationStoreProtocol = LocationStore.shared
    lazy var imageCache: ImageCacheProtocol = ImageCacheService.shared
    lazy var config: AppConfigurationProtocol = AppConfiguration.shared
    lazy var buoyCacheService = BuoyCacheService.shared
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Testing Support
    
    /// Create a mock dependencies instance for testing
    static func createMock() -> AppDependencies {
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

