//
//  ContentModerationService.swift
//  TrebleSurf
//
//  Service for content moderation and reporting
//

import Foundation

class ContentModerationService: ContentModerationServiceProtocol {
    private let apiClient: APIClientProtocol
    private let logger: ErrorLoggerProtocol
    
    init(apiClient: APIClientProtocol, logger: ErrorLoggerProtocol) {
        self.apiClient = apiClient
        self.logger = logger
    }
    
    /// Submit a content report to the backend
    /// - Parameters:
    ///   - surfReportId: ID of the surf report being reported
    ///   - reason: Reason for the report
    ///   - description: Optional additional details
    /// - Returns: True if report was successfully submitted
    func submitReport(
        surfReportId: String,
        reason: ReportReason,
        description: String?
    ) async throws -> Bool {
        logger.log("Submitting content report for surf report: \(surfReportId)", level: .info, category: .api)
        
        // Create request body
        let requestBody: [String: Any] = [
            "surfReportId": surfReportId,
            "reason": reason.rawValue,
            "description": description ?? ""
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            logger.log("Failed to serialize report request body", level: .error, category: .api)
            throw NSError(domain: "ContentModeration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])
        }
        
        do {
            let response: ReportSubmissionResponse = try await apiClient.makeFlexibleRequest(
                to: "/api/reports/submit",
                method: "POST",
                requiresAuth: true,
                body: bodyData
            )
            
            if response.success {
                logger.log("Content report submitted successfully: \(response.reportId ?? "unknown")", level: .info, category: .api)
                return true
            } else {
                logger.log("Content report submission failed: \(response.message ?? "unknown error")", level: .error, category: .api)
                return false
            }
        } catch {
            logger.log("Error submitting content report: \(error.localizedDescription)", level: .error, category: .api)
            throw error
        }
    }
}
