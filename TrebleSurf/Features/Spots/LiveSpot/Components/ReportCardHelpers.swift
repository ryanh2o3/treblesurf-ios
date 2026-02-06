// ReportCardHelpers.swift
import Foundation

/// Shared helper functions used by RecentReportCard and MatchingReportCard
enum ReportCardHelpers {
    static func mediaTypeIcon(for mediaType: String?) -> String {
        switch mediaType?.lowercased() {
        case "image":
            return "photo"
        case "video":
            return "video"
        case "both":
            return "photo.on.rectangle"
        default:
            return "photo"
        }
    }

    static func mediaTypeText(for mediaType: String?) -> String {
        switch mediaType?.lowercased() {
        case "image":
            return "Photo"
        case "video":
            return "Video"
        case "both":
            return "Media"
        default:
            return "Photo"
        }
    }
}
