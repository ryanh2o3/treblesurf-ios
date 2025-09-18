// SpotData.swift
import Foundation

struct SpotData: Codable, Identifiable, Equatable {
    let beachDirection: Int
    let idealSwellDirection: String
    let latitude: Double
    let longitude: Double
    let type: String
    let countryRegionSpot: String
    let image: String
    var imageString: String?
    
    
    // Computed properties
    var id: String { countryRegionSpot.replacingOccurrences(of: "/", with: "#") }
    var name: String { countryRegionSpot.split(separator: "/").last.map(String.init) ?? "" }
    

    enum CodingKeys: String, CodingKey {
        case beachDirection = "BeachDirection"
        case idealSwellDirection = "IdealSwellDirection"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case type = "Type"
        case countryRegionSpot = "country_region_spot"
        case image = "Image"
        case imageString = "ImageString"
    }
    
    // Equatable conformance
    static func == (lhs: SpotData, rhs: SpotData) -> Bool {
        return lhs.id == rhs.id
    }
}
