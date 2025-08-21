import Foundation

// MARK: - API Error Response Model

struct APIErrorResponse: Codable {
    let error: String
    let message: String
    let help: String
}



// MARK: - Image Upload Response Models

struct PresignedUploadResponse: Codable {
    let uploadUrl: String
    let imageKey: String
    let expiresAt: String
}


