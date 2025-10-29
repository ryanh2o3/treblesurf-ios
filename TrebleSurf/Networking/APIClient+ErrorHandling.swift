//
//  APIClient+ErrorHandling.swift
//  TrebleSurf
//
//  Extension to add proper error handling to APIClient
//

import Foundation

extension APIClient {
    
    // MARK: - Error Handling Utilities
    
    /// Get a logger instance (non-isolated)
    private var logger: ErrorLoggerProtocol {
        // Create a local instance to avoid actor isolation issues
        ErrorLogger(minimumLogLevel: .info, enableConsoleOutput: true, enableOSLog: true)
    }
    
    /// Convert NSError or standard Error to TrebleSurfError
    func handleError(_ error: Error, context: String) -> TrebleSurfError {
        logger.log("Processing error in APIClient", level: .debug, category: .api)
        logger.log("Error: \(error)", level: .debug, category: .api)
        logger.log("Context: \(context)", level: .debug, category: .api)
        
        // Check if it's already a TrebleSurfError
        if let trebleError = error as? TrebleSurfError {
            logger.logError(trebleError, context: context)
            return trebleError
        }
        
        // Check for API error in NSError userInfo
        if let nsError = error as NSError?,
           let errorData = nsError.userInfo["errorData"] as? Data,
           let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: errorData) {
            let trebleError = TrebleSurfError.apiError(error: apiError.error, message: apiError.message, help: apiError.help)
            logger.logError(trebleError, context: context)
            return trebleError
        }
        
        // Convert standard error
        let trebleError = TrebleSurfError.from(error)
        logger.logError(trebleError, context: context)
        return trebleError
    }
    
    /// Validate HTTP response and data
    func validateResponse(data: Data?, response: URLResponse?, error: Error?, context: String) throws -> Data {
        // Check for network errors
        if let error = error {
            logger.log("Network error in \(context)", level: .error, category: .network)
            throw handleError(error, context: context)
        }
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.log("Invalid response type in \(context)", level: .error, category: .api)
            throw TrebleSurfError.invalidResponse
        }
        
        logger.log("HTTP Status: \(httpResponse.statusCode) for \(context)", level: .debug, category: .api)
        
        // Check for data
        guard let data = data else {
            logger.log("No data received in \(context)", level: .error, category: .api)
            throw TrebleSurfError.httpError(statusCode: httpResponse.statusCode, message: "No data received")
        }
        
        // Check for HTML response (indicates backend error)
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("text/html") {
            logger.log("Received HTML instead of JSON in \(context)", level: .error, category: .api)
            throw TrebleSurfError.invalidResponse
        }
        
        // Validate status code
        guard (200...299).contains(httpResponse.statusCode) else {
            logger.log("HTTP error status: \(httpResponse.statusCode) in \(context)", level: .warning, category: .api)
            
            // Try to decode API error
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                logger.log("API Error: \(apiError.error) - \(apiError.message)", level: .error, category: .api)
                throw TrebleSurfError.apiError(error: apiError.error, message: apiError.message, help: apiError.help)
            }
            
            // Generic HTTP error
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TrebleSurfError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
        
        return data
    }
    
    /// Decode response data with proper error handling
    func decodeResponse<T: Decodable>(_ data: Data, context: String) throws -> T {
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            logger.log("Successfully decoded response for \(context)", level: .debug, category: .api)
            return decoded
        } catch {
            logger.log("Decoding failed for \(context)", level: .error, category: .api)
            logger.log("Decoding error: \(error)", level: .debug, category: .api)
            
            // Log the response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                logger.log("Response data: \(responseString.prefix(200))...", level: .debug, category: .api)
            }
            
            throw TrebleSurfError.decodingFailed(error)
        }
    }
    
    /// Encode request body with proper error handling
    func encodeRequestBody<T: Encodable>(_ body: T, context: String) throws -> Data {
        do {
            let encoded = try JSONEncoder().encode(body)
            logger.log("Successfully encoded request body for \(context)", level: .debug, category: .api)
            return encoded
        } catch {
            logger.log("Encoding failed for \(context)", level: .error, category: .api)
            logger.log("Encoding error: \(error)", level: .debug, category: .api)
            throw TrebleSurfError.encodingFailed(error)
        }
    }
    
    /// Log request details
    func logRequest(endpoint: String, method: String, hasBody: Bool, hasAuth: Bool) {
        logger.log("[\(method)] \(endpoint)", level: .info, category: .api)
        if hasBody {
            logger.log("Request includes body", level: .debug, category: .api)
        }
        if hasAuth {
            logger.log("Request includes authentication", level: .debug, category: .api)
        }
    }
    
    /// Log response success
    func logResponseSuccess(endpoint: String, dataSize: Int) {
        logger.log("✅ Success: \(endpoint) (\(dataSize) bytes)", level: .info, category: .api)
    }
}

