import Foundation
struct SurfReportResponse: Decodable {
    let consistency: String
    let imageKey: String?
    let messiness: String
    let quality: String
    let reporter: String
    let surfSize: String
    let time: String
    let userEmail: String
    let windAmount: String
    let windDirection: String
    let countryRegionSpot: String
    let dateReported: String

    enum CodingKeys: String, CodingKey {
        case consistency = "Consistency"
        case imageKey = "ImageKey"
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
    }
}

// Identifiable type for app usage
class SurfReport: ObservableObject, Identifiable {
    let id = UUID()
    let consistency: String
    let imageKey: String?
    let messiness: String
    let quality: String
    let reporter: String
    let surfSize: String
    let time: String
    let userEmail: String
    let windAmount: String
    let windDirection: String
    let countryRegionSpot: String
    let dateReported: String
    
    @Published var imageData: String? // Make this observable
    
    init(consistency: String, imageKey: String?, messiness: String, quality: String, reporter: String, surfSize: String, time: String, userEmail: String, windAmount: String, windDirection: String, countryRegionSpot: String, dateReported: String, imageData: String? = nil) {
        self.consistency = consistency
        self.imageKey = imageKey
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
        self.imageData = imageData
    }
}

extension SurfReport {
    convenience init(from response: SurfReportResponse) {
        self.init(
            consistency: response.consistency,
            imageKey: response.imageKey,
            messiness: response.messiness,
            quality: response.quality,
            reporter: response.reporter,
            surfSize: response.surfSize,
            time: response.time,
            userEmail: response.userEmail,
            windAmount: response.windAmount,
            windDirection: response.windDirection,
            countryRegionSpot: response.countryRegionSpot,
            dateReported: response.dateReported
        )
    }
}

struct SurfReportImageResponse: Decodable {
    
    let imageData: String
    let contentType: String
    
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
