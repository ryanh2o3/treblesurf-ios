struct BuoyResponse: Decodable {
    let AirTemperature: Double?
    let AtmosphericPressure: Double?
    let DewPoint: Double?
    let Gust: Double?
    let MaxHeight: Double?
    let MaxPeriod: Double?
    let MeanWaveDirection: Int?
    let RelativeHumidity: Double?
    let Salinity: Double?
    let SeaTemperature: Double?
    let SprTp: Double?
    let ThTp: Double?
    let WaveHeight: Double?
    let WavePeriod: Double?
    let WindDirection: Int?
    let WindSpeed: Double?
    let dataDateTime: String?
    let name: String
    let region_buoy: String
    
    // Custom decoding initializer to handle type mismatches
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required fields
        name = try container.decode(String.self, forKey: .name)
        region_buoy = try container.decode(String.self, forKey: .region_buoy)
        
        // Decode optional fields using flexible decoding methods
        AirTemperature = try container.decodeFlexibleDouble(forKey: .AirTemperature)
        AtmosphericPressure = try container.decodeFlexibleDouble(forKey: .AtmosphericPressure)
        DewPoint = try container.decodeFlexibleDouble(forKey: .DewPoint)
        Gust = try container.decodeFlexibleDouble(forKey: .Gust)
        MaxHeight = try container.decodeFlexibleDouble(forKey: .MaxHeight)
        MaxPeriod = try container.decodeFlexibleDouble(forKey: .MaxPeriod)
        MeanWaveDirection = try container.decodeFlexibleInt(forKey: .MeanWaveDirection)
        RelativeHumidity = try container.decodeFlexibleDouble(forKey: .RelativeHumidity)
        Salinity = try container.decodeFlexibleDouble(forKey: .Salinity)
        SeaTemperature = try container.decodeFlexibleDouble(forKey: .SeaTemperature)
        SprTp = try container.decodeFlexibleDouble(forKey: .SprTp)
        ThTp = try container.decodeFlexibleDouble(forKey: .ThTp)
        WaveHeight = try container.decodeFlexibleDouble(forKey: .WaveHeight)
        WavePeriod = try container.decodeFlexibleDouble(forKey: .WavePeriod)
        WindDirection = try container.decodeFlexibleInt(forKey: .WindDirection)
        WindSpeed = try container.decodeFlexibleDouble(forKey: .WindSpeed)
        dataDateTime = try? container.decode(String.self, forKey: .dataDateTime)
    }
    
    private enum CodingKeys: String, CodingKey {
        case AirTemperature, AtmosphericPressure, DewPoint, Gust, MaxHeight, MaxPeriod
        case MeanWaveDirection, RelativeHumidity, Salinity, SeaTemperature, SprTp, ThTp
        case WaveHeight, WavePeriod, WindDirection, WindSpeed, dataDateTime, name, region_buoy
    }
}

// MARK: - Utility Extensions for Flexible Decoding
extension KeyedDecodingContainer {
    /// Decodes a value that might be either a Double or a String representation of a Double
    func decodeFlexibleDouble(forKey key: K) throws -> Double? {
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return doubleValue
        }
        
        if let stringValue = try? decode(String.self, forKey: key) {
            // Handle common string representations
            switch stringValue.lowercased() {
            case "n/a", "na", "null", "", "-":
                return nil
            default:
                return Double(stringValue)
            }
        }
        
        return nil
    }
    
    /// Decodes a value that might be either an Int or a String representation of an Int
    func decodeFlexibleInt(forKey key: K) throws -> Int? {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }
        
        if let stringValue = try? decode(String.self, forKey: key) {
            // Handle common string representations
            switch stringValue.lowercased() {
            case "n/a", "na", "null", "", "-":
                return nil
            default:
                return Int(stringValue)
            }
        }
        
        return nil
    }
}

struct BuoyLocation: Decodable, Equatable {
    let region_buoy: String
    let latitude: Double
    let longitude: Double
    let name: String
    
    // Equatable conformance
    static func == (lhs: BuoyLocation, rhs: BuoyLocation) -> Bool {
        return lhs.name == rhs.name && lhs.region_buoy == rhs.region_buoy
    }
}
