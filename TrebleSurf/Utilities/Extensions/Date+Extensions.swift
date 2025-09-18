import Foundation

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}

extension Date {
    /// Parses a dateReported string that contains ISO date + timezone + additional data
    /// Format 1: "2025-08-16 10:31:39 +0000 UTC_27ebc05e-625a-4c05-add5-5e6ef33f8b8e"
    /// Format 2: "2025-08-21 12:52:44.831528104 +0000 UTC m=+48.107848006_ryancpatton0@gmail.com"
    static func parseDateReported(_ dateString: String) -> Date? {
        // Try to extract just the date and time part before any additional data
        var dateTimeString: String?
        
        // Check for the new format first (more specific): UTC m=+...
        if let components = dateString.components(separatedBy: " UTC m=").first {
            dateTimeString = components
        }
        // Check for the old format: UTC_UUID
        else if let components = dateString.components(separatedBy: " UTC_").first {
            dateTimeString = components
        }
        // Check for the new simple format: "2025-09-08 09:27:28" (no timezone info)
        else if dateString.matches("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$") {
            dateTimeString = dateString
        }
        
        guard let dateTimeString = dateTimeString else { 
            return nil 
        }
        
        // Handle different date formats
        var normalizedString = dateTimeString
        
        // Check if this is the simple format without timezone (new format)
        if dateTimeString.matches("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$") {
            // This is our new format - parse as UTC since backend always stores UTC
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(abbreviation: "UTC") // Backend always stores as UTC
            
            if let date = formatter.date(from: dateTimeString) {
                return date
            }
        }
        
        // Handle legacy formats with timezone info
        // If it ends with +0000, try replacing it with Z (UTC)
        if normalizedString.hasSuffix("+0000") {
            normalizedString = String(normalizedString.dropLast(5)) + "Z"
        }
        
        // Try using ISO8601DateFormatter first (more flexible)
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: normalizedString) {
            return date
        }
        
        // Fallback to DateFormatter with various formats
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        // Try different date formats
        let dateFormats = [
            "yyyy-MM-dd HH:mm:ss.SSSSSSSSS Z",     // With nanoseconds and Z
            "yyyy-MM-dd HH:mm:ss Z",               // Without nanoseconds, with Z
            "yyyy-MM-dd HH:mm:ss.SSSSSSSSS ZZZZ",  // With nanoseconds and timezone
            "yyyy-MM-dd HH:mm:ss ZZZZ"             // Without nanoseconds, with timezone
        ]
        
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: normalizedString) {
                return date
            }
        }
        
        // Last resort: try stripping nanoseconds and parsing
        if normalizedString.contains(".") {
            let components = normalizedString.components(separatedBy: ".")
            if components.count >= 2 {
                let withoutNanoseconds = components[0] + "Z"
                
                if let date = isoFormatter.date(from: withoutNanoseconds) {
                    return date
                }
                
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                if let date = formatter.date(from: withoutNanoseconds) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    /// Formats the date in a user-friendly format: "16 Aug 12:31PM"
    func formatForDisplay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM h:mma"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone.current // Use local timezone
        
        return formatter.string(from: self)
    }
}
