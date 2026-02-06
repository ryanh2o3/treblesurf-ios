//
//  ErrorHandler.swift
//  TrebleSurf
//
//  Protocol-based error handling service
//

import Foundation

// MARK: - Error Handler Protocol

protocol ErrorHandlerProtocol {
    /// Process an error and return a user-presentable error
    func handle(_ error: Error, context: String?) -> TrebleSurfError
    
    /// Process an error and return presentation model
    func handleForPresentation(_ error: Error, context: String?) -> ErrorPresentation
    
    /// Validate API response and convert to error if needed
    func validateAPIResponse(_ data: Data, statusCode: Int) throws
    
    /// Extract API error from NSError userInfo
    func extractAPIError(from error: Error) -> APIErrorResponse?
}

// MARK: - Error Handler Implementation

final class ErrorHandler: ErrorHandlerProtocol {
    
    private let logger: ErrorLoggerProtocol
    
    init(logger: ErrorLoggerProtocol) {
        self.logger = logger
    }
    
    // MARK: - Handle Error
    
    func handle(_ error: Error, context: String? = nil) -> TrebleSurfError {
        let trebleError = TrebleSurfError.from(error)
        logger.logError(trebleError, context: context)
        return trebleError
    }
    
    func handleForPresentation(_ error: Error, context: String? = nil) -> ErrorPresentation {
        let trebleError = handle(error, context: context)
        return ErrorPresentation(from: trebleError)
    }
    
    // MARK: - API Response Validation
    
    func validateAPIResponse(_ data: Data, statusCode: Int) throws {
        // Check for successful status codes
        guard (200...299).contains(statusCode) else {
            // Try to decode API error response
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw TrebleSurfError.apiError(error: apiError.error, message: apiError.message, help: apiError.help)
            }
            
            // Generic HTTP error
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TrebleSurfError.httpError(statusCode: statusCode, message: message)
        }
    }
    
    // MARK: - Extract API Error
    
    func extractAPIError(from error: Error) -> APIErrorResponse? {
        // Check if error is NSError with errorData in userInfo
        if let nsError = error as NSError?,
           let errorData = nsError.userInfo["errorData"] as? Data {
            return try? JSONDecoder().decode(APIErrorResponse.self, from: errorData)
        }
        
        // Check if error is NSError with apiError in userInfo
        if let nsError = error as NSError?,
           let apiError = nsError.userInfo["apiError"] as? APIErrorResponse {
            return apiError
        }
        
        // Check if the error message contains API error JSON
        if let nsError = error as NSError?,
           let errorMessage = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
           errorMessage.contains("\"error\"") && errorMessage.contains("\"message\""),
           let data = errorMessage.data(using: .utf8) {
            return try? JSONDecoder().decode(APIErrorResponse.self, from: data)
        }
        
        return nil
    }
}

// MARK: - Error Presentation Model

/// User-facing error presentation model
struct ErrorPresentation {
    let title: String
    let message: String
    let helpText: String
    let actions: [ErrorAction]
    let fieldErrors: [String: String]
    let errorCode: String
    let isRetryable: Bool
    
    init(from error: TrebleSurfError) {
        self.title = Self.titleForError(error)
        self.message = error.userMessage
        self.helpText = error.recoverySuggestions.joined(separator: "\n")
        self.actions = Self.actionsForError(error)
        self.fieldErrors = error.fieldErrors
        self.errorCode = error.errorCode
        self.isRetryable = error.isRetryable
    }
    
    // Custom initializer for manual creation
    init(title: String, 
         message: String, 
         helpText: String, 
         actions: [ErrorAction] = [],
         fieldErrors: [String: String] = [:],
         errorCode: String = "CUSTOM",
         isRetryable: Bool = false) {
        self.title = title
        self.message = message
        self.helpText = helpText
        self.actions = actions
        self.fieldErrors = fieldErrors
        self.errorCode = errorCode
        self.isRetryable = isRetryable
    }
    
    // MARK: - Error Title
    
    private static func titleForError(_ error: TrebleSurfError) -> String {
        switch error.category {
        case .network:
            return "Connection Issue"
        case .authentication:
            return "Authentication Required"
        case .validation:
            return "Validation Error"
        case .api:
            return "Request Failed"
        case .media:
            return "Media Error"
        case .cache:
            return "Data Access Error"
        case .dataProcessing:
            return "Data Error"
        case .configuration:
            return "Configuration Error"
        case .unknown:
            return "Unexpected Error"
        }
    }
    
    // MARK: - Error Actions
    
    private static func actionsForError(_ error: TrebleSurfError) -> [ErrorAction] {
        var actions: [ErrorAction] = []
        
        // Add retry action if retryable
        if error.isRetryable {
            actions.append(.retry)
        }
        
        // Add specific actions based on error type
        switch error {
        case .notAuthenticated, .sessionExpired:
            actions.append(.signIn)
        case .imageNotSurfRelated, .imageValidationFailed:
            actions.append(.chooseNewImage)
        case .noConnection:
            actions.append(.checkConnection)
        default:
            if !error.isRetryable {
                actions.append(.dismiss)
            }
        }
        
        return actions
    }
}

// MARK: - Error Action

enum ErrorAction: Equatable {
    case retry
    case signIn
    case chooseNewImage
    case chooseNewVideo
    case checkConnection
    case dismiss
    case contactSupport
    case openSettings
    
    var title: String {
        switch self {
        case .retry: return "Try Again"
        case .signIn: return "Sign In"
        case .chooseNewImage: return "Choose Another Image"
        case .chooseNewVideo: return "Choose Another Video"
        case .checkConnection: return "Check Connection"
        case .dismiss: return "OK"
        case .contactSupport: return "Contact Support"
        case .openSettings: return "Open Settings"
        }
    }
    
    var isDestructive: Bool {
        return false
    }
    
    var isPrimary: Bool {
        switch self {
        case .retry, .signIn:
            return true
        default:
            return false
        }
    }
}

// MARK: - Field Error Helper

extension ErrorPresentation {
    /// Get error message for a specific field
    func errorForField(_ fieldName: String) -> String? {
        return fieldErrors[fieldName]
    }

    /// Check if there are any field errors
    var hasFieldErrors: Bool {
        return !fieldErrors.isEmpty
    }

    /// Get all field names with errors
    var errorFieldNames: [String] {
        return Array(fieldErrors.keys)
    }

    /// Whether the error requires re-authentication
    var requiresAuthentication: Bool {
        return actions.contains(.signIn)
    }

    /// Whether the error requires choosing a new image
    var requiresImageRetry: Bool {
        return actions.contains(.chooseNewImage)
    }

    /// The field name associated with this error (first field error key, if any)
    var fieldName: String? {
        return fieldErrors.keys.first
    }
}

