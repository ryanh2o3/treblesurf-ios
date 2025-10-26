//
//  TimestampParser.swift
//  TrebleSurf
//
//  Created by Cursor
//

import Foundation

/// Service for parsing timestamps from various formats
struct TimestampParser {
    private init() {}
    
    /// Parse timestamp with multiple format support
    /// Supports:
    /// - "2025-07-12 19:57:27 +0000 UTC"
    /// - "2025-08-18 22:32:30.819091968 +0000 UTC m=+293.995127367"
    /// - ISO8601 format
    /// - Returns nil if parsing fails
    static func parse(_ timestamp: String) -> Date? {
        // Format 1: "2025-07-12 19:57:27 +0000 UTC"
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ 'UTC'"
        formatter1.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = formatter1.date(from: timestamp) {
            return date
        }
        
        // Format 2: "2025-08-18 22:32:30.819091968 +0000 UTC m=+293.995127367"
        // Extract the main timestamp part before the Go runtime info
        if timestamp.contains(" m=") {
            let components = timestamp.components(separatedBy: " m=")
            if let mainTimestamp = components.first {
                let formatter2 = DateFormatter()
                formatter2.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSSSS ZZZZZ 'UTC'"
                formatter2.locale = Locale(identifier: "en_US_POSIX")
                
                if let date = formatter2.date(from: mainTimestamp) {
                    return date
                }
                
                // Try without microseconds
                let formatter3 = DateFormatter()
                formatter3.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ 'UTC'"
                formatter3.locale = Locale(identifier: "en_US_POSIX")
                
                if let date = formatter3.date(from: mainTimestamp) {
                    return date
                }
            }
        }
        
        // Format 3: Try ISO8601 format
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: timestamp) {
            return date
        }
        
        // Format 4: Failed to parse
        print("Failed to parse timestamp: \(timestamp)")
        return nil
    }
    
    /// Format a date for display
    /// - Parameters:
    ///   - date: The date to format
    ///   - format: The format string (default: "d MMM, h:mma")
    /// - Returns: Formatted date string
    static func formatDate(_ date: Date, format: String = "d MMM, h:mma") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

