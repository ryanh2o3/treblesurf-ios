//
//  AppConfiguration.swift
//  TrebleSurf
//
//  Created by Ryan Patton
//

import Foundation
import UIKit

/// Protocol defining the app's configuration
protocol AppConfigurationProtocol {
    var apiBaseURL: String { get }
    var cacheExpirationInterval: TimeInterval { get }
    var spotCacheExpirationInterval: TimeInterval { get }
    var imageCacheExpirationInterval: TimeInterval { get }
    var defaultCountry: String { get }
    var defaultRegion: String { get }
    var defaultBuoys: [String] { get }
    var isSimulator: Bool { get }
}

/// Centralized app configuration
final class AppConfiguration: AppConfigurationProtocol {
    static let shared = AppConfiguration()
    
    var apiBaseURL: String {
        #if DEBUG
        return UIDevice.current.isSimulator ? "http://localhost:8080" : "https://treblesurf.com"
        #else
        return "https://treblesurf.com"
        #endif
    }
    
    var cacheExpirationInterval: TimeInterval {
        30 * 60 // 30 minutes
    }
    
    var spotCacheExpirationInterval: TimeInterval {
        60 * 60 * 24 * 4 // 4 days
    }
    
    var imageCacheExpirationInterval: TimeInterval {
        30 * 24 * 60 * 60 // 30 days
    }
    
    var defaultCountry: String {
        return "Ireland"
    }
    
    var defaultRegion: String {
        return "Donegal"
    }
    
    var defaultBuoys: [String] {
        return ["M4", "M6"]
    }
    
    var isSimulator: Bool {
        UIDevice.current.isSimulator
    }
    
    init() {}
}

