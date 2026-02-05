//
//  BaseViewModel.swift
//  TrebleSurf
//
//  Base ViewModel with standardized error handling
//

import Foundation
import SwiftUI

// MARK: - Base ViewModel Protocol

@MainActor
protocol BaseViewModelProtocol: ObservableObject {
    var errorPresentation: ErrorPresentation? { get set }
    var isLoading: Bool { get set }
    
    func handleError(_ error: Error, context: String?)
    func clearError()
}

// MARK: - Base ViewModel Implementation

@MainActor
class BaseViewModel: ObservableObject, BaseViewModelProtocol {
    
    // MARK: - Published Properties
    
    @Published var errorPresentation: ErrorPresentation?
    @Published var isLoading: Bool = false
    @Published var fieldErrors: [String: String] = [:]
    
    // MARK: - Dependencies
    
    let errorHandler: ErrorHandlerProtocol
    let logger: ErrorLoggerProtocol
    
    // MARK: - Initialization
    
    init(errorHandler: ErrorHandlerProtocol? = nil, logger: ErrorLoggerProtocol? = nil) {
        let loggerInstance = logger ?? ErrorLogger(minimumLogLevel: .info, enableConsoleOutput: true, enableOSLog: true)
        self.logger = loggerInstance
        self.errorHandler = errorHandler ?? ErrorHandler(logger: loggerInstance)
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error, context: String? = nil) {
        logger.log("Handling error in \(type(of: self))", level: .debug, category: .general)
        
        let trebleError = TrebleSurfError.from(error)
        logger.logError(trebleError, context: context)
        
        errorPresentation = ErrorPresentation(from: trebleError)
    }
    
    func clearError() {
        errorPresentation = nil
    }
    
    // MARK: - Loading State
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    // MARK: - Safe Task Execution
    
    /// Execute an async task with automatic error handling and loading state
    func executeTask(
        showLoading: Bool = true,
        context: String? = nil,
        operation: @escaping () async throws -> Void
    ) {
        Task {
            if showLoading {
                setLoading(true)
            }
            
            do {
                try await operation()
            } catch {
                handleError(error, context: context ?? "Task execution")
            }
            
            if showLoading {
                setLoading(false)
            }
        }
    }
    
    /// Execute an async task that returns a value with automatic error handling
    func executeTask<T>(
        showLoading: Bool = true,
        context: String? = nil,
        operation: @escaping () async throws -> T
    ) async -> T? {
        if showLoading {
            setLoading(true)
        }
        
        defer {
            if showLoading {
                setLoading(false)
            }
        }
        
        do {
            return try await operation()
        } catch {
            handleError(error, context: context ?? "Task execution")
            return nil
        }
    }
}

// MARK: - Field Validation Support

extension BaseViewModel {
    
    /// Handle validation error with field-specific messages
    func handleValidationError(_ error: TrebleSurfError) {
        logger.log("Handling validation error", level: .debug, category: .validation)
        
        // Extract field errors
        fieldErrors = error.fieldErrors
        
        // Show general error presentation
        errorPresentation = ErrorPresentation(from: error)
    }
    
    /// Clear error for a specific field
    func clearFieldError(_ fieldName: String) {
        fieldErrors.removeValue(forKey: fieldName)
    }
    
    /// Clear all field errors
    func clearAllFieldErrors() {
        fieldErrors.removeAll()
    }
    
    /// Get error message for a specific field
    func fieldError(for fieldName: String) -> String? {
        return fieldErrors[fieldName]
    }
    
    /// Check if a field has an error
    func hasFieldError(_ fieldName: String) -> Bool {
        return fieldErrors[fieldName] != nil
    }
}

// MARK: - Retry Support

extension BaseViewModel {
    
    /// Retry the last failed operation
    func retry(operation: @escaping () async throws -> Void) {
        logger.log("Retrying operation", level: .info, category: .general)
        clearError()
        executeTask(operation: operation)
    }
}

// MARK: - Example Usage

#if DEBUG
@MainActor
class ExampleViewModel: BaseViewModel {
    @Published var data: String?
    
    func fetchData() {
        executeTask(context: "Fetch Data") {
            // Simulate API call
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Simulate error
            throw TrebleSurfError.noConnection
            
            // If successful:
            // self.data = "Success"
        }
    }
    
    func submitForm(email: String, password: String) {
        executeTask(context: "Submit Form") {
            // Validate fields
            guard !email.isEmpty else {
                throw TrebleSurfError.missingRequiredField(field: "email")
            }
            
            guard !password.isEmpty else {
                throw TrebleSurfError.missingRequiredField(field: "password")
            }
            
            // Submit
            try await Task.sleep(nanoseconds: 500_000_000)
            
            self.logger.log("Form submitted successfully", level: .info, category: .general)
        }
    }
}
#endif

