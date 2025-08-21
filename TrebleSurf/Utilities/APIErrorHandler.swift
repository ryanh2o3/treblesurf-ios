import Foundation
import SwiftUI

// MARK: - API Error Handler

class APIErrorHandler: ObservableObject {
    static let shared = APIErrorHandler()
    
    // MARK: - Error Types
    
    enum ErrorType: String, CaseIterable {
        case missingRequiredFields = "Missing required fields"
        case invalidSurfSize = "Invalid surf size"
        case invalidWindAmount = "Invalid wind amount"
        case invalidWindDirection = "Invalid wind direction"
        case invalidConsistency = "Invalid consistency"
        case invalidQuality = "Invalid quality"
        case invalidMessiness = "Invalid messiness"
        case imageValidationFailed = "Image validation failed"
        case invalidImageData = "Invalid image data"
        case authenticationRequired = "Authentication required"
        case userInformationError = "User information error"
        case invalidRequestFormat = "Invalid request format"
        case imageNotFound = "Image not found"
        case failedToGenerateUploadURL = "Failed to generate upload URL"
        case failedToRetrieveReports = "Failed to retrieve reports"
        
        // New error types from the updated backend
        case imageNotSurfRelated = "Image not surf-related"
        case imageAnalysisFailed = "Image analysis failed"
        case imageUploadFailed = "Image upload failed"
        case imageRetrievalFailed = "Image retrieval failed"
        
        var isFieldSpecific: Bool {
            switch self {
            case .missingRequiredFields, .invalidSurfSize, .invalidWindAmount, 
                 .invalidWindDirection, .invalidConsistency, .invalidQuality, 
                 .invalidMessiness:
                return true
            default:
                return false
            }
        }
        
        var fieldName: String? {
            switch self {
            case .invalidSurfSize:
                return "surfSize"
            case .invalidWindAmount:
                return "windAmount"
            case .invalidWindDirection:
                return "windDirection"
            case .invalidConsistency:
                return "consistency"
            case .invalidQuality:
                return "quality"
            case .invalidMessiness:
                return "messiness"
            case .imageValidationFailed, .imageNotSurfRelated, .imageAnalysisFailed, 
                 .imageUploadFailed, .invalidImageData, .imageRetrievalFailed:
                return "image"
            default:
                return nil
            }
        }
    }
    
    // MARK: - Error Display Model
    
    struct ErrorDisplay {
        let title: String
        let message: String
        let help: String
        let errorType: ErrorType?
        let fieldName: String?
        let isRetryable: Bool
        let requiresAuthentication: Bool
        let requiresImageRetry: Bool
        
        init(from apiError: APIErrorResponse) {
            self.title = apiError.error
            self.message = apiError.message
            self.help = apiError.help
            
            // Determine error type based on the new simplified error format
            self.errorType = ErrorType.allCases.first { errorType in
                // Map the new backend error messages to our error types
                switch errorType {
                case .imageNotSurfRelated:
                    return apiError.error.contains("Image not surf-related") || 
                           apiError.error.contains("not surf-related")
                case .imageAnalysisFailed:
                    return apiError.error.contains("Image analysis failed") || 
                           apiError.error.contains("analysis failed")
                case .imageUploadFailed:
                    return apiError.error.contains("Image upload failed") || 
                           apiError.error.contains("upload failed")
                case .invalidImageData:
                    return apiError.error.contains("Invalid image data") || 
                           apiError.error.contains("invalid format")
                case .imageRetrievalFailed:
                    return apiError.error.contains("Image retrieval failed") || 
                           apiError.error.contains("not found")
                case .imageValidationFailed:
                    return apiError.error.contains("Image validation failed") || 
                           apiError.error.contains("validation failed")
                case .missingRequiredFields:
                    return apiError.error.contains("Missing required fields")
                case .invalidSurfSize:
                    return apiError.error.contains("Invalid surf size")
                case .invalidWindAmount:
                    return apiError.error.contains("Invalid wind amount")
                case .invalidWindDirection:
                    return apiError.error.contains("Invalid wind direction")
                case .invalidConsistency:
                    return apiError.error.contains("Invalid consistency")
                case .invalidQuality:
                    return apiError.error.contains("Invalid quality")
                case .invalidMessiness:
                    return apiError.error.contains("Invalid messiness")
                case .authenticationRequired:
                    return apiError.error.contains("Authentication required") || 
                           apiError.error.contains("authentication")
                case .userInformationError:
                    return apiError.error.contains("User information error")
                case .invalidRequestFormat:
                    return apiError.error.contains("Invalid request format")
                case .imageNotFound:
                    return apiError.error.contains("Image not found")
                case .failedToGenerateUploadURL:
                    return apiError.error.contains("Failed to generate upload URL")
                case .failedToRetrieveReports:
                    return apiError.error.contains("Failed to retrieve reports")
                }
            }
            
            // Get field name if it's a field-specific error
            self.fieldName = self.errorType?.fieldName
            
            // Determine if error is retryable based on new error types
            let retryableErrors = [
                "Failed to generate upload URL",
                "Failed to retrieve reports",
                "User information error",
                "Image not found",
                "Image upload failed",
                "Image analysis failed"
            ]
            self.isRetryable = retryableErrors.contains { retryableError in
                return apiError.error.contains(retryableError)
            }
            
            // Determine if authentication is required
            self.requiresAuthentication = apiError.error.contains("Authentication required") || 
                                       apiError.error.contains("authentication")
            
            // Determine if image retry is needed - updated for new error types
            self.requiresImageRetry = (apiError.error.contains("validation") && 
                                    (apiError.error.contains("image") || apiError.error.contains("Image"))) ||
                                    apiError.error.contains("Image validation failed") ||
                                    apiError.error.contains("Image not surf-related") ||
                                    apiError.error.contains("Invalid image data") ||
                                    apiError.error.contains("Image analysis failed") ||
                                    apiError.error.contains("Image retrieval failed")
        }
        
        // Custom initializer for manual creation
        init(title: String, message: String, help: String, errorType: ErrorType?, fieldName: String?, isRetryable: Bool, requiresAuthentication: Bool, requiresImageRetry: Bool) {
            self.title = title
            self.message = message
            self.help = help
            self.errorType = errorType
            self.fieldName = fieldName
            self.isRetryable = isRetryable
            self.requiresAuthentication = requiresAuthentication
            self.requiresImageRetry = requiresImageRetry
        }
    }
    
    // MARK: - Error Handling Methods
    
    func handleAPIError(_ error: Error) -> ErrorDisplay? {
        // Check if it's an API error response
        if let apiError = extractAPIError(from: error) {
            return ErrorDisplay(from: apiError)
        }
        
        // Handle network and other errors
        return handleGenericError(error)
    }
    
    private func extractAPIError(from error: Error) -> APIErrorResponse? {
        // Try to extract API error from various error types
        if let nsError = error as NSError? {
            
            // Check if the error has API error data in userInfo
            if let errorData = nsError.userInfo["errorData"] as? Data {
                do {
                    let apiError = try JSONDecoder().decode(APIErrorResponse.self, from: errorData)
                    return apiError
                } catch {
                    return nil
                }
            }
            
            // Check if the error message contains API error information
            if let errorMessage = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                
                // Try to parse as JSON if it looks like an API error
                if errorMessage.contains("\"error\"") && errorMessage.contains("\"message\"") {
                    if let data = errorMessage.data(using: .utf8) {
                        do {
                            let apiError = try JSONDecoder().decode(APIErrorResponse.self, from: data)
                            return apiError
                        } catch {
                            return nil
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func handleGenericError(_ error: Error) -> ErrorDisplay {
        let nsError = error as NSError
        
        switch nsError.code {
        case NSURLErrorCannotConnectToHost, NSURLErrorTimedOut:
            return ErrorDisplay(
                title: "Connection Error",
                message: "Unable to connect to the server. Please check your internet connection and try again.",
                help: "Make sure you have a stable internet connection and try submitting your report again.",
                errorType: nil,
                fieldName: nil,
                isRetryable: true,
                requiresAuthentication: false,
                requiresImageRetry: false
            )
            
        case NSURLErrorNotConnectedToInternet:
            return ErrorDisplay(
                title: "No Internet Connection",
                message: "You appear to be offline. Please check your internet connection.",
                help: "Connect to the internet and try submitting your report again.",
                errorType: nil,
                fieldName: nil,
                isRetryable: true,
                requiresAuthentication: false,
                requiresImageRetry: false
            )
            
        case 401, 403:
            return ErrorDisplay(
                title: "Authentication Required",
                message: "Your session has expired or you need to log in.",
                help: "Please log in again to continue submitting your surf report.",
                errorType: nil,
                fieldName: nil,
                isRetryable: false,
                requiresAuthentication: true,
                requiresImageRetry: false
            )
            
        case 500, 502, 503, 504:
            return ErrorDisplay(
                title: "Server Error",
                message: "The server is experiencing issues. Please try again later.",
                help: "This is a temporary issue. Please wait a few minutes and try again.",
                errorType: nil,
                fieldName: nil,
                isRetryable: true,
                requiresAuthentication: false,
                requiresImageRetry: false
            )
            
        default:
            return ErrorDisplay(
                title: "Unexpected Error",
                message: "An unexpected error occurred. Please try again.",
                help: "If the problem persists, please contact support.",
                errorType: nil,
                fieldName: nil,
                isRetryable: true,
                requiresAuthentication: false,
                requiresImageRetry: false
            )
        }
    }
    
    // MARK: - Field Validation Error Handling
    
    func getFieldValidationError(for fieldName: String, error: ErrorDisplay) -> String? {
        guard error.fieldName == fieldName else { return nil }
        return error.help
    }
    
    // MARK: - User Action Guidance
    
    func getActionGuidance(for error: ErrorDisplay) -> [String] {
        var actions: [String] = []
        
        if error.requiresAuthentication {
            actions.append("Log in to continue")
        }
        
        if error.requiresImageRetry {
            actions.append("Try uploading a different image")
            actions.append("Ensure the image shows ocean, waves, beach, or coastline")
        }
        
        if error.isRetryable {
            actions.append("Try again")
        }
        
        if actions.isEmpty {
            actions.append("Contact support if the problem persists")
        }
        
        return actions
    }
}
