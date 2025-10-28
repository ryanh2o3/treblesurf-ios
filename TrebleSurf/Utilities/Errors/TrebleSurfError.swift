//
//  TrebleSurfError.swift
//  TrebleSurf
//
//  Unified error handling system for TrebleSurf
//

import Foundation

// MARK: - Base Error Protocol

/// Protocol that all TrebleSurf errors conform to
protocol TrebleSurfErrorProtocol: LocalizedError {
    /// Unique error code for tracking and analytics
    var errorCode: String { get }
    
    /// Category of the error
    var category: ErrorCategory { get }
    
    /// Whether this error can be retried
    var isRetryable: Bool { get }
    
    /// User-facing error message
    var userMessage: String { get }
    
    /// Technical details for logging/debugging
    var technicalDetails: String { get }
    
    /// Suggested recovery actions
    var recoverySuggestions: [String] { get }
    
    /// Underlying error if this wraps another error
    var underlyingError: Error? { get }
}

// MARK: - Error Categories

enum ErrorCategory: String {
    case network
    case authentication
    case validation
    case api
    case dataProcessing
    case cache
    case media
    case configuration
    case unknown
}

// MARK: - Main Error Enum

enum TrebleSurfError: TrebleSurfErrorProtocol {
    // Network Errors
    case noConnection
    case timeout
    case connectionLost
    case serverUnavailable
    case invalidURL(url: String)
    
    // Authentication Errors
    case notAuthenticated
    case sessionExpired
    case authenticationFailed(reason: String)
    case csrfTokenMissing
    
    // API Errors
    case httpError(statusCode: Int, message: String?)
    case apiError(error: String, message: String, help: String)
    case invalidResponse
    case decodingFailed(Error)
    case encodingFailed(Error)
    
    // Validation Errors
    case missingRequiredField(field: String)
    case invalidFieldValue(field: String, reason: String)
    case validationFailed(fields: [String: String])
    
    // Media Errors
    case imageValidationFailed(reason: String)
    case imageNotSurfRelated
    case imageUploadFailed(reason: String)
    case imageNotFound(key: String)
    case videoUploadFailed(reason: String)
    case videoNotFound(key: String)
    case mediaProcessingFailed(reason: String)
    
    // Cache Errors
    case cacheReadFailed(key: String, Error)
    case cacheWriteFailed(key: String, Error)
    case cacheExpired(key: String)
    
    // Data Processing Errors
    case dataCorrupted(reason: String)
    case parsingFailed(reason: String)
    case unexpectedDataFormat
    
    // Unknown/Wrapped Errors
    case unknown(Error)
    
    // MARK: - Error Code
    
    var errorCode: String {
        switch self {
        // Network
        case .noConnection: return "NET_001"
        case .timeout: return "NET_002"
        case .connectionLost: return "NET_003"
        case .serverUnavailable: return "NET_004"
        case .invalidURL: return "NET_005"
            
        // Authentication
        case .notAuthenticated: return "AUTH_001"
        case .sessionExpired: return "AUTH_002"
        case .authenticationFailed: return "AUTH_003"
        case .csrfTokenMissing: return "AUTH_004"
            
        // API
        case .httpError: return "API_001"
        case .apiError: return "API_002"
        case .invalidResponse: return "API_003"
        case .decodingFailed: return "API_004"
        case .encodingFailed: return "API_005"
            
        // Validation
        case .missingRequiredField: return "VAL_001"
        case .invalidFieldValue: return "VAL_002"
        case .validationFailed: return "VAL_003"
            
        // Media
        case .imageValidationFailed: return "MEDIA_001"
        case .imageNotSurfRelated: return "MEDIA_002"
        case .imageUploadFailed: return "MEDIA_003"
        case .imageNotFound: return "MEDIA_004"
        case .videoUploadFailed: return "MEDIA_005"
        case .videoNotFound: return "MEDIA_006"
        case .mediaProcessingFailed: return "MEDIA_007"
            
        // Cache
        case .cacheReadFailed: return "CACHE_001"
        case .cacheWriteFailed: return "CACHE_002"
        case .cacheExpired: return "CACHE_003"
            
        // Data Processing
        case .dataCorrupted: return "DATA_001"
        case .parsingFailed: return "DATA_002"
        case .unexpectedDataFormat: return "DATA_003"
            
        // Unknown
        case .unknown: return "UNKNOWN_001"
        }
    }
    
    // MARK: - Category
    
    var category: ErrorCategory {
        switch self {
        case .noConnection, .timeout, .connectionLost, .serverUnavailable, .invalidURL:
            return .network
        case .notAuthenticated, .sessionExpired, .authenticationFailed, .csrfTokenMissing:
            return .authentication
        case .missingRequiredField, .invalidFieldValue, .validationFailed:
            return .validation
        case .httpError, .apiError, .invalidResponse, .decodingFailed, .encodingFailed:
            return .api
        case .imageValidationFailed, .imageNotSurfRelated, .imageUploadFailed, .imageNotFound,
             .videoUploadFailed, .videoNotFound, .mediaProcessingFailed:
            return .media
        case .cacheReadFailed, .cacheWriteFailed, .cacheExpired:
            return .cache
        case .dataCorrupted, .parsingFailed, .unexpectedDataFormat:
            return .dataProcessing
        case .unknown:
            return .unknown
        }
    }
    
    // MARK: - Retryability
    
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .connectionLost, .serverUnavailable:
            return true
        case .sessionExpired:
            return true
        case .httpError(let statusCode, _):
            return statusCode >= 500 || statusCode == 429 // Server errors and rate limiting
        case .imageUploadFailed, .videoUploadFailed, .mediaProcessingFailed:
            return true
        case .cacheReadFailed, .cacheWriteFailed:
            return true
        default:
            return false
        }
    }
    
    // MARK: - User Message
    
    var userMessage: String {
        switch self {
        // Network
        case .noConnection:
            return "No internet connection available."
        case .timeout:
            return "The request took too long to complete."
        case .connectionLost:
            return "Connection was interrupted."
        case .serverUnavailable:
            return "The server is temporarily unavailable."
        case .invalidURL:
            return "Invalid request configuration."
            
        // Authentication
        case .notAuthenticated:
            return "You need to sign in to access this feature."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .authenticationFailed(let reason):
            return reason
        case .csrfTokenMissing:
            return "Security validation failed. Please try again."
            
        // API
        case .httpError(let statusCode, let message):
            if let message = message {
                return message
            }
            return "Server returned error: \(statusCode)"
        case .apiError(_, let message, _):
            return message
        case .invalidResponse:
            return "Received invalid response from server."
        case .decodingFailed:
            return "Failed to process server response."
        case .encodingFailed:
            return "Failed to prepare request data."
            
        // Validation
        case .missingRequiredField(let field):
            return "\(field.capitalized) is required."
        case .invalidFieldValue(let field, let reason):
            return "\(field.capitalized): \(reason)"
        case .validationFailed:
            return "Please check the form for errors."
            
        // Media
        case .imageValidationFailed(let reason):
            return "Image validation failed: \(reason)"
        case .imageNotSurfRelated:
            return "Please upload an image showing ocean, waves, beach, or coastline."
        case .imageUploadFailed(let reason):
            return "Failed to upload image: \(reason)"
        case .imageNotFound:
            return "Image not found."
        case .videoUploadFailed(let reason):
            return "Failed to upload video: \(reason)"
        case .videoNotFound:
            return "Video not found."
        case .mediaProcessingFailed(let reason):
            return "Media processing failed: \(reason)"
            
        // Cache
        case .cacheReadFailed, .cacheWriteFailed, .cacheExpired:
            return "Failed to access cached data."
            
        // Data Processing
        case .dataCorrupted(let reason):
            return "Data is corrupted: \(reason)"
        case .parsingFailed(let reason):
            return "Failed to parse data: \(reason)"
        case .unexpectedDataFormat:
            return "Received unexpected data format."
            
        // Unknown
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    // MARK: - Technical Details
    
    var technicalDetails: String {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message ?? "No message")"
        case .apiError(let error, let message, let help):
            return "API Error - \(error): \(message) | Help: \(help)"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidFieldValue(let field, let reason):
            return "Invalid value for \(field): \(reason)"
        case .validationFailed(let fields):
            return "Validation failed for fields: \(fields)"
        case .imageValidationFailed(let reason):
            return "Image validation failed: \(reason)"
        case .imageUploadFailed(let reason):
            return "Image upload failed: \(reason)"
        case .imageNotFound(let key):
            return "Image not found with key: \(key)"
        case .videoUploadFailed(let reason):
            return "Video upload failed: \(reason)"
        case .videoNotFound(let key):
            return "Video not found with key: \(key)"
        case .mediaProcessingFailed(let reason):
            return "Media processing failed: \(reason)"
        case .cacheReadFailed(let key, let error):
            return "Cache read failed for key \(key): \(error.localizedDescription)"
        case .cacheWriteFailed(let key, let error):
            return "Cache write failed for key \(key): \(error.localizedDescription)"
        case .cacheExpired(let key):
            return "Cache expired for key: \(key)"
        case .dataCorrupted(let reason):
            return "Data corrupted: \(reason)"
        case .parsingFailed(let reason):
            return "Parsing failed: \(reason)"
        case .unknown(let error):
            return "Unknown error: \(error)"
        default:
            return userMessage
        }
    }
    
    // MARK: - Recovery Suggestions
    
    var recoverySuggestions: [String] {
        switch self {
        case .noConnection:
            return ["Check your internet connection", "Try again when connected"]
        case .timeout, .connectionLost:
            return ["Check your internet connection", "Try again"]
        case .serverUnavailable:
            return ["Wait a few minutes", "Try again later"]
        case .notAuthenticated:
            return ["Sign in to continue"]
        case .sessionExpired:
            return ["Sign in again to continue"]
        case .authenticationFailed:
            return ["Check your credentials", "Try signing in again"]
        case .csrfTokenMissing:
            return ["Restart the app", "Sign in again"]
        case .httpError(let statusCode, _):
            if statusCode >= 500 {
                return ["Wait a few minutes", "Try again later"]
            } else if statusCode == 429 {
                return ["Wait a moment", "Try again in a few seconds"]
            }
            return ["Try again", "Contact support if the problem persists"]
        case .apiError(_, _, let help):
            return [help, "Contact support if the problem persists"]
        case .invalidResponse, .decodingFailed:
            return ["Try again", "Update the app to the latest version"]
        case .imageNotSurfRelated:
            return ["Upload an image showing surf conditions", "Ensure the image includes ocean, waves, beach, or coastline"]
        case .imageUploadFailed, .videoUploadFailed, .mediaProcessingFailed:
            return ["Try uploading a different file", "Check your file size and format", "Try again"]
        case .validationFailed:
            return ["Check all required fields", "Fix any validation errors"]
        case .missingRequiredField, .invalidFieldValue:
            return ["Fill in all required information", "Check the field requirements"]
        default:
            return ["Try again", "Contact support if the problem persists"]
        }
    }
    
    // MARK: - Underlying Error
    
    var underlyingError: Error? {
        switch self {
        case .decodingFailed(let error), .encodingFailed(let error),
             .cacheReadFailed(_, let error), .cacheWriteFailed(_, let error),
             .unknown(let error):
            return error
        default:
            return nil
        }
    }
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        return userMessage
    }
    
    var failureReason: String? {
        return technicalDetails
    }
    
    var recoverySuggestion: String? {
        return recoverySuggestions.first
    }
}

// MARK: - Error Conversion

extension TrebleSurfError {
    /// Convert from standard Error types to TrebleSurfError
    static func from(_ error: Error) -> TrebleSurfError {
        // If already a TrebleSurfError, return it
        if let trebleError = error as? TrebleSurfError {
            return trebleError
        }
        
        // Check if it's an NSError with specific codes
        if let nsError = error as NSError? {
            return fromNSError(nsError)
        }
        
        // Check for URLError
        if let urlError = error as? URLError {
            return fromURLError(urlError)
        }
        
        // Check for DecodingError
        if let decodingError = error as? DecodingError {
            return .decodingFailed(decodingError)
        }
        
        // Check for EncodingError
        if let encodingError = error as? EncodingError {
            return .encodingFailed(encodingError)
        }
        
        // Default to unknown
        return .unknown(error)
    }
    
    private static func fromNSError(_ error: NSError) -> TrebleSurfError {
        // Check for API error data in userInfo
        if let errorData = error.userInfo["errorData"] as? Data,
           let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: errorData) {
            return .apiError(error: apiError.error, message: apiError.message, help: apiError.help)
        }
        
        // Check for network errors
        switch error.code {
        case NSURLErrorNotConnectedToInternet:
            return .noConnection
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorNetworkConnectionLost:
            return .connectionLost
        case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
            return .serverUnavailable
        case 401, 403:
            return .sessionExpired
        case 500...599:
            return .httpError(statusCode: error.code, message: error.localizedDescription)
        default:
            return .unknown(error)
        }
    }
    
    private static func fromURLError(_ error: URLError) -> TrebleSurfError {
        switch error.code {
        case .notConnectedToInternet:
            return .noConnection
        case .timedOut:
            return .timeout
        case .networkConnectionLost:
            return .connectionLost
        case .cannotConnectToHost, .cannotFindHost:
            return .serverUnavailable
        default:
            return .unknown(error)
        }
    }
}

// MARK: - Field-Specific Error Information

extension TrebleSurfError {
    /// Get the field name if this is a field-specific error
    var fieldName: String? {
        switch self {
        case .missingRequiredField(let field), .invalidFieldValue(let field, _):
            return field
        case .imageValidationFailed, .imageNotSurfRelated, .imageUploadFailed, .imageNotFound:
            return "image"
        case .videoUploadFailed, .videoNotFound:
            return "video"
        default:
            return nil
        }
    }
    
    /// Get all field errors if this is a validation error
    var fieldErrors: [String: String] {
        switch self {
        case .validationFailed(let fields):
            return fields
        case .missingRequiredField(let field):
            return [field: "This field is required"]
        case .invalidFieldValue(let field, let reason):
            return [field: reason]
        default:
            return [:]
        }
    }
}

