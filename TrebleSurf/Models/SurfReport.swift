import Foundation
import UIKit
struct SurfReportResponse: Decodable {
    let consistency: String
    let imageKey: String?
    let videoKey: String?
    let messiness: String
    let quality: String
    let reporter: String
    let surfSize: String
    let time: String
    let userEmail: String?
    let windAmount: String
    let windDirection: String
    let countryRegionSpot: String
    let dateReported: String
    let mediaType: String?
    let iosValidated: Bool?

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
    }
}

// Identifiable type for app usage
class SurfReport: ObservableObject, Identifiable {
    let id = UUID()
    let consistency: String
    let imageKey: String?
    let videoKey: String?
    let messiness: String
    let quality: String
    let reporter: String
    let surfSize: String
    let time: String
    let userEmail: String?
    let windAmount: String
    let windDirection: String
    let countryRegionSpot: String
    let dateReported: String
    let mediaType: String?
    let iosValidated: Bool?
    
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
    
    init(consistency: String, imageKey: String?, videoKey: String?, messiness: String, quality: String, reporter: String, surfSize: String, time: String, userEmail: String?, windAmount: String, windDirection: String, countryRegionSpot: String, dateReported: String, mediaType: String? = nil, iosValidated: Bool? = nil, imageData: String? = nil, videoData: String? = nil) {
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
        self.imageData = imageData
        self.videoData = videoData
    }
}

extension SurfReport {
    convenience init(from response: SurfReportResponse) {
        self.init(
            consistency: response.consistency,
            imageKey: response.imageKey,
            videoKey: response.videoKey,
            messiness: response.messiness,
            quality: response.quality,
            reporter: response.reporter,
            surfSize: response.surfSize,
            time: response.time,
            userEmail: response.userEmail,
            windAmount: response.windAmount,
            windDirection: response.windDirection,
            countryRegionSpot: response.countryRegionSpot,
            dateReported: response.dateReported,
            mediaType: response.mediaType,
            iosValidated: response.iosValidated
        )
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
