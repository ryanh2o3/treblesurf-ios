//
//  ReportReason.swift
//  TrebleSurf
//
//  Content moderation - report reasons
//

import Foundation

/// Reasons for reporting inappropriate content
enum ReportReason: String, CaseIterable, Codable {
    case inappropriate = "Inappropriate Content"
    case spam = "Spam"
    case offensive = "Offensive Language"
    case notSurfRelated = "Not Surf Related"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .inappropriate:
            return "exclamationmark.triangle.fill"
        case .spam:
            return "envelope.badge.fill"
        case .offensive:
            return "hand.raised.fill"
        case .notSurfRelated:
            return "questionmark.circle.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .inappropriate:
            return "Nudity, violence, or explicit content"
        case .spam:
            return "Advertising or repetitive content"
        case .offensive:
            return "Hate speech or harassment"
        case .notSurfRelated:
            return "Content unrelated to surfing"
        case .other:
            return "Other violation of guidelines"
        }
    }
}
