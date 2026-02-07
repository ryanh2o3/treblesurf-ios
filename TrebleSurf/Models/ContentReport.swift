//
//  ContentReport.swift
//  TrebleSurf
//
//  Model for content reports
//

import Foundation

/// Model for submitting a content report
struct ContentReport: Codable {
    let surfReportId: String
    let reason: ReportReason
    let description: String?
    let timestamp: Date
    
    init(surfReportId: String, reason: ReportReason, description: String? = nil) {
        self.surfReportId = surfReportId
        self.reason = reason
        self.description = description
        self.timestamp = Date()
    }
}

/// Response from backend after submitting a report
struct ReportSubmissionResponse: Codable {
    let success: Bool
    let message: String?
    let reportId: String?
}
