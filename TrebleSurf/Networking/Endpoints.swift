//
//  Endpoints.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

extension APIClient {
    func fetchSpots(country: String, region: String, completion: @escaping (Result<[SpotData], Error>) -> Void) {
        let endpoint = "/api/spots?country=\(country)&region=\(region)"
        
        // Use existing request method but specify the return type as [String]
        request(endpoint, method: "GET") { (result: Result<[SpotData], Error>) in
            completion(result)
        }
    }
    
    // Convenience method for the specific Donegal, Ireland endpoint
    func fetchDonegalSpots(completion: @escaping (Result<[SpotData], Error>) -> Void) {
        fetchSpots(country: "Ireland", region: "Donegal", completion: completion)
    }
    
    func fetchLocationInfo(country: String, region: String, spot: String, completion: @escaping (Result<SpotData, Error>) -> Void) {
        let endpoint = "/api/locationInfo?country=\(country)&region=\(region)&spot=\(spot)"
        

        // Use existing request method but specify the return type as [String]
        request(endpoint, method: "GET") { (result: Result<SpotData, Error>) in
            
            completion(result)
        }
    }
    
}

extension APIClient {
    func fetchBuoys(region: String, completion: @escaping (Result<[BuoyLocation], Error>) -> Void) {
        let endpoint = "/api/regionBuoys?region=\(region)"
        
        request(endpoint, method: "GET") { (result: Result<[BuoyLocation], Error>) in
            completion(result)
        }
    }
}

extension APIClient {
    func fetchBuoyData(buoyNames: [String], completion: @escaping (Result<[BuoyResponse], Error>) -> Void) {
        let buoysParam = buoyNames.joined(separator: ",")
        let endpoint = "/api/getMultipleBuoyData?buoys=\(buoysParam)"
        
        request(endpoint, method: "GET") { (result: Result<[BuoyResponse], Error>) in
            completion(result)
        }
    }
}

extension APIClient {
    func fetchLast24HoursBuoyData(buoyName: String, completion: @escaping (Result<[BuoyResponse], Error>) -> Void) {
        let endpoint = "/api/getLast24BuoyData?buoyName=\(buoyName)"
        
        request(endpoint, method: "GET") { (result: Result<[BuoyResponse], Error>) in
            completion(result)
        }
    }
}

extension APIClient {
    func fetchSurfReports(country: String, region: String, spot: String, completion: @escaping (Result<[SurfReportResponse], Error>) -> Void) {
        let endpoint = "/api/getTodaySpotReports?country=\(country)&region=\(region)&spot=\(spot)"
        
        // Use flexible request method that can handle authentication gracefully
        makeFlexibleRequest(to: endpoint, requiresAuth: true) { (result: Result<[SurfReportResponse], Error>) in
            switch result {
            case .success(let surfReport):
                completion(.success(surfReport))
            case .failure(let error):
                print("Failed to fetch surf reports: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

extension APIClient {
    func getReportImage(key: String, completion: @escaping (Result<SurfReportImageResponse, Error>) -> Void) {
        let endpoint = "/api/getReportImage?key=\(key)"
        
        // Use flexible request method that can handle authentication gracefully
        makeFlexibleRequest(to: endpoint, requiresAuth: true) { (result: Result<SurfReportImageResponse, Error>) in
            switch result {
            case .success(let reportImage):
                completion(.success(reportImage))
            case .failure(let error):
                print("Failed to fetch report image: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}


// current conditions api calls
extension APIClient {
    func fetchCurrentConditions(country: String, region: String, spot: String, completion: @escaping (Result<[CurrentConditionsResponse], Error>) -> Void) {
        let endpoint = "/api/currentConditions?country=\(country)&region=\(region)&spot=\(spot)"
        print("Fetching current conditions: \(spot)")
        request(endpoint, method: "GET") { (result: Result<[CurrentConditionsResponse], Error>) in
            completion(result)
        }
    }
    
    func fetchForecast(country: String, region: String, spot: String, completion: @escaping (Result<[ForecastResponse], Error>) -> Void) {
        let endpoint = "/api/forecast?country=\(country)&region=\(region)&spot=\(spot)"
        print("Fetching forecast: \(spot)")
        request(endpoint, method: "GET") { (result: Result<[ForecastResponse], Error>) in
            completion(result)
        }
    }
}
