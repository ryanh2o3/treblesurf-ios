import Foundation
import UIKit

// Helper type to decode either String or Double
enum StringOrDouble: Decodable {
    case string(String)
    case double(Double)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(StringOrDouble.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Double"))
        }
    }
    
    var doubleValue: Double? {
        switch self {
        case .string(let str):
            return Double(str)
        case .double(let value):
            return value
        }
    }
}

struct SurfReportResponse: Decodable {
    let consistency: String?
    let imageKey: String?
    let videoKey: String?
    let messiness: String?
    let quality: String?
    let reporter: String?
    let surfSize: String?
    let time: String
    let userEmail: String?
    let windAmount: String?
    let windDirection: String?
    let countryRegionSpot: String
    let dateReported: String
    let mediaType: String?
    let iosValidated: Bool?
    
    // Matching condition fields (optional, only present for matching condition reports)
    let buoySimilarity: Double?
    let windSimilarity: Double?
    let combinedSimilarity: Double?
    let matchedBuoy: String?
    let historicalBuoyWaveHeight: StringOrDouble?
    let historicalBuoyWaveDirection: StringOrDouble?
    let historicalBuoyPeriod: StringOrDouble?
    let historicalWindSpeed: Double?
    let historicalWindDirection: Double?
    let travelTimeHours: Double?

    enum CodingKeys: String, CodingKey {
        case consistency = "Consistency"
        case imageKey = "ImageKey"
        case videoKey = "VideoKey"
        case messiness = "Messiness"
        case quality = "Quality"
        case reporter = "Reporter"
        case surfSize = "SurfSize"
        case time = "Time"
        case userEmail = "UserEmail"
        case windAmount = "WindAmount"
        case windDirection = "WindDirection"
        case countryRegionSpot = "country_region_spot"
        case dateReported = "dateReported"
        case mediaType = "MediaType"
        case iosValidated = "IOSValidated"
        case buoySimilarity = "buoy_similarity"
        case windSimilarity = "wind_similarity"
        case combinedSimilarity = "combined_similarity"
        case matchedBuoy = "matched_buoy"
        case historicalBuoyWaveHeight = "historical_buoy_wave_height"
        case historicalBuoyWaveDirection = "historical_buoy_wave_direction"
        case historicalBuoyPeriod = "historical_buoy_period"
        case historicalWindSpeed = "historical_wind_speed"
        case historicalWindDirection = "historical_wind_direction"
        case travelTimeHours = "travel_time_hours"
    }
}

// Identifiable type for app usage
class SurfReport: ObservableObject, Identifiable {
    let id = UUID()
    let consistency: String  // Stored with default empty string
    let imageKey: String?
    let videoKey: String?
    let messiness: String  // Stored with default empty string
    let quality: String  // Stored with default empty string
    let reporter: String  // Stored with default "Anonymous"
    let surfSize: String  // Stored with default empty string
    let time: String
    let userEmail: String?
    let windAmount: String  // Stored with default empty string
    let windDirection: String  // Stored with default empty string
    let countryRegionSpot: String
    let dateReported: String
    let mediaType: String?
    let iosValidated: Bool?
    
    // Matching condition fields
    let buoySimilarity: Double?
    let windSimilarity: Double?
    let combinedSimilarity: Double?
    let matchedBuoy: String?
    let historicalBuoyWaveHeight: Double?
    let historicalBuoyWaveDirection: Double?
    let historicalBuoyPeriod: Double?
    let historicalWindSpeed: Double?
    let historicalWindDirection: Double?
    let travelTimeHours: Double?
    
    @Published var imageData: String? // Make this observable
    @Published var videoData: String? // Make this observable
    @Published var videoThumbnail: UIImage? // Video thumbnail for preview
    
    /// Computed property that returns a user-friendly formatted date
    var formattedDateReported: String {
        if let date = Date.parseDateReported(dateReported) {
            return date.formatForDisplay()
        }
        return dateReported // Fallback to original string if parsing fails
    }
    
    init(consistency: String, imageKey: String?, videoKey: String?, messiness: String, quality: String, reporter: String, surfSize: String, time: String, userEmail: String?, windAmount: String, windDirection: String, countryRegionSpot: String, dateReported: String, mediaType: String? = nil, iosValidated: Bool? = nil, buoySimilarity: Double? = nil, windSimilarity: Double? = nil, combinedSimilarity: Double? = nil, matchedBuoy: String? = nil, historicalBuoyWaveHeight: Double? = nil, historicalBuoyWaveDirection: Double? = nil, historicalBuoyPeriod: Double? = nil, historicalWindSpeed: Double? = nil, historicalWindDirection: Double? = nil, travelTimeHours: Double? = nil, imageData: String? = nil, videoData: String? = nil) {
        self.consistency = consistency
        self.imageKey = imageKey
        self.videoKey = videoKey
        self.messiness = messiness
        self.quality = quality
        self.reporter = reporter
        self.surfSize = surfSize
        self.time = time
        self.userEmail = userEmail
        self.windAmount = windAmount
        self.windDirection = windDirection
        self.countryRegionSpot = countryRegionSpot
        self.dateReported = dateReported
        self.mediaType = mediaType
        self.iosValidated = iosValidated
        self.buoySimilarity = buoySimilarity
        self.windSimilarity = windSimilarity
        self.combinedSimilarity = combinedSimilarity
        self.matchedBuoy = matchedBuoy
        self.historicalBuoyWaveHeight = historicalBuoyWaveHeight
        self.historicalBuoyWaveDirection = historicalBuoyWaveDirection
        self.historicalBuoyPeriod = historicalBuoyPeriod
        self.historicalWindSpeed = historicalWindSpeed
        self.historicalWindDirection = historicalWindDirection
        self.travelTimeHours = travelTimeHours
        self.imageData = imageData
        self.videoData = videoData
    }
}

extension SurfReport {
    convenience init(from response: SurfReportResponse) {
        // Format the time for display
        let formattedTime: String
        if let date = Self.parseTime(response.time) {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM, h:mma"
            formatter.locale = Locale(identifier: "en_US")
            formatter.timeZone = TimeZone.current
            formattedTime = formatter.string(from: date)
        } else {
            formattedTime = "Invalid Date"
        }
        
        self.init(
            consistency: response.consistency ?? "",
            imageKey: response.imageKey,
            videoKey: response.videoKey,
            messiness: response.messiness ?? "",
            quality: response.quality ?? "",
            reporter: response.reporter ?? "Anonymous",
            surfSize: response.surfSize ?? "",
            time: formattedTime,
            userEmail: response.userEmail,
            windAmount: response.windAmount ?? "",
            windDirection: response.windDirection ?? "",
            countryRegionSpot: response.countryRegionSpot,
            dateReported: response.dateReported,
            mediaType: response.mediaType,
            iosValidated: response.iosValidated,
            buoySimilarity: response.buoySimilarity,
            windSimilarity: response.windSimilarity,
            combinedSimilarity: response.combinedSimilarity,
            matchedBuoy: response.matchedBuoy,
            historicalBuoyWaveHeight: response.historicalBuoyWaveHeight?.doubleValue,
            historicalBuoyWaveDirection: response.historicalBuoyWaveDirection?.doubleValue,
            historicalBuoyPeriod: response.historicalBuoyPeriod?.doubleValue,
            historicalWindSpeed: response.historicalWindSpeed,
            historicalWindDirection: response.historicalWindDirection,
            travelTimeHours: response.travelTimeHours
        )
    }
    
    /// Parse timestamp with multiple format support
    private static func parseTime(_ timestamp: String) -> Date? {
        // Format 1: "2025-07-12 19:57:27 +0000 UTC"
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ 'UTC'"
        formatter1.locale = Locale(identifier: "en_US_POSIX")
        formatter1.timeZone = TimeZone(abbreviation: "UTC")
        
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
                formatter2.timeZone = TimeZone(abbreviation: "UTC")
                
                if let date = formatter2.date(from: mainTimestamp) {
                    return date
                }
                
                // Try without nanoseconds
                let formatter3 = DateFormatter()
                formatter3.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ 'UTC'"
                formatter3.locale = Locale(identifier: "en_US_POSIX")
                formatter3.timeZone = TimeZone(abbreviation: "UTC")
                
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
        
        return nil
    }
}

struct SurfReportImageResponse: Decodable {
    let imageData: String?
    let contentType: String?
    
    enum CodingKeys: String, CodingKey {
        case imageData
        case contentType
    }
    
    init(imageData: String?, contentType: String?) {
        self.imageData = imageData
        self.contentType = contentType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageData = try container.decodeIfPresent(String.self, forKey: .imageData)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
    }
}

struct SurfReportVideoResponse: Decodable {
    let videoData: String
    let contentType: String
}

struct PresignedVideoViewResponse: Decodable {
    let viewURL: String?
    let expiresAt: String?
    
    enum CodingKeys: String, CodingKey {
        case viewURL
        case expiresAt
    }
    
    init(viewURL: String?, expiresAt: String?) {
        self.viewURL = viewURL
        self.expiresAt = expiresAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        viewURL = try container.decodeIfPresent(String.self, forKey: .viewURL)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
    }
}

struct SurfReportSubmissionResponse: Decodable {
    let message: String
    
    // Optional fields that might be present in some responses
    let success: Bool?
    let reportId: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case success
        case reportId = "report_id"
    }
    
    // Custom initializer to handle the case where only message is present
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // message is required
        message = try container.decode(String.self, forKey: .message)
        
        // success and reportId are optional
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        reportId = try container.decodeIfPresent(String.self, forKey: .reportId)
    }
}

struct PresignedVideoUploadResponse: Decodable {
    let uploadUrl: String
    let videoKey: String
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case uploadUrl
        case videoKey
        case expiresAt
    }
}
