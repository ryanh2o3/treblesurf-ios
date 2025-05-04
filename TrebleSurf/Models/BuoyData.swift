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
}
