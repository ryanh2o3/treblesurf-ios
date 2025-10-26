//
//  TrebleSurfError.swift
//  TrebleSurf
//
//  Created by Ryan Patton
//

import Foundation

/// App-specific error types with user-friendly messages
enum TrebleSurfError: LocalizedError {
    case networkError(underlying: Error)
    case authenticationError
    case decodingError(Error)
    case invalidData(String)
    case cacheError(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationError:
            return "Your session has expired. Please log in again."
        case .decodingError(let error):
            return "Failed to parse server response: \(error.localizedDescription)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .cacheError(let message):
            return "Cache error: \(message)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .authenticationError:
            return "Please sign in again to continue."
        case .decodingError:
            return "The server response format has changed. Please update the app."
        case .invalidData:
            return "Please try again with valid input."
        case .cacheError:
            return "Please try restarting the app."
        case .unknown:
            return "If the problem persists, please contact support."
        }
    }
}

