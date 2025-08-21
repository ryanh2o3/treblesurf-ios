//
//  AuthModels.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import Foundation

// MARK: - User Model
struct User: Codable {
    let email: String
    let name: String
    let picture: String
    let familyName: String
    let givenName: String
    let createdAt: String?
    let lastLogin: String?
    let theme: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case name
        case picture
        case familyName = "family_name"
        case givenName = "given_name"
        case createdAt = "created_at"
        case lastLogin = "last_login"
        case theme
    }
}

// MARK: - Auth Response Models
struct AuthResponse: Codable {
    let user: User
}

struct ValidateResponse: Codable {
    let valid: Bool
    let authType: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case valid
        case authType = "auth_type"
        case user
    }
}

struct LogoutResponse: Codable {
    let message: String
}

// MARK: - Session Models
struct SessionInfo: Codable {
    let sessionId: String
    let expiresAt: String
    let current: Bool
    let lastActive: String?
    let userAgent: String?
    let ipAddress: String?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case expiresAt = "expires_at"
        case current
        case lastActive = "last_active"
        case userAgent = "user_agent"
        case ipAddress = "ip_address"
    }
}

struct SessionsResponse: Codable {
    let sessions: [SessionInfo]
    let count: Int
}

