//
//  APIClient+ErrorHandling.swift
//  TrebleSurf
//
//  Extension to add proper error handling to APIClient
//

import Foundation

extension APIClient {
    
    // MARK: - Error Handling Utilities
    
    /// Convert NSError or standard Error to TrebleSurfError
    func handleError(_ error: Error, context: String) -> TrebleSurfError {
        let deps = AppDependencies.shared
        let logger = deps.errorLogger
        
        logger.debug("Processing error in APIClient", category: .api)
        logger.debug("Error: \(error)", category: .api)
        logger.debug("Context: \(context)", category: .api)
        
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
        let logger = AppDependencies.shared.errorLogger
        
        // Check for network errors
        if let error = error {
            logger.error("Network error in \(context)", category: .network)
            throw handleError(error, context: context)
        }
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type in \(context)", category: .api)
            throw TrebleSurfError.invalidResponse
        }
        
        logger.debug("HTTP Status: \(httpResponse.statusCode) for \(context)", category: .api)
        
        // Check for data
        guard let data = data else {
            logger.error("No data received in \(context)", category: .api)
            throw TrebleSurfError.httpError(statusCode: httpResponse.statusCode, message: "No data received")
        }
        
        // Check for HTML response (indicates backend error)
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("text/html") {
            logger.error("Received HTML instead of JSON in \(context)", category: .api)
            throw TrebleSurfError.invalidResponse
        }
        
        // Validate status code
        guard (200...299).contains(httpResponse.statusCode) else {
            logger.warning("HTTP error status: \(httpResponse.statusCode) in \(context)", category: .api)
            
            // Try to decode API error
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                logger.error("API Error: \(apiError.error) - \(apiError.message)", category: .api)
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
        let logger = AppDependencies.shared.errorLogger
        
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            logger.debug("Successfully decoded response for \(context)", category: .api)
            return decoded
        } catch {
            logger.error("Decoding failed for \(context)", category: .api)
            logger.debug("Decoding error: \(error)", category: .api)
            
            // Log the response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Response data: \(responseString.prefix(200))...", category: .api)
            }
            
            throw TrebleSurfError.decodingFailed(error)
        }
    }
    
    /// Encode request body with proper error handling
    func encodeRequestBody<T: Encodable>(_ body: T, context: String) throws -> Data {
        let logger = AppDependencies.shared.errorLogger
        
        do {
            let encoded = try JSONEncoder().encode(body)
            logger.debug("Successfully encoded request body for \(context)", category: .api)
            return encoded
        } catch {
            logger.error("Encoding failed for \(context)", category: .api)
            logger.debug("Encoding error: \(error)", category: .api)
            throw TrebleSurfError.encodingFailed(error)
        }
    }
    
    /// Log request details
    func logRequest(endpoint: String, method: String, hasBody: Bool, hasAuth: Bool) {
        let logger = AppDependencies.shared.errorLogger
        logger.info("[\(method)] \(endpoint)", category: .api)
        if hasBody {
            logger.debug("Request includes body", category: .api)
        }
        if hasAuth {
            logger.debug("Request includes authentication", category: .api)
        }
    }
    
    /// Log response success
    func logResponseSuccess(endpoint: String, dataSize: Int) {
        let logger = AppDependencies.shared.errorLogger
        logger.info("✅ Success: \(endpoint) (\(dataSize) bytes)", category: .api)
    }
}

