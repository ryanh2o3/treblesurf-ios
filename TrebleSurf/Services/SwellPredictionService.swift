//
//  SwellPredictionService.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 01/01/2025.
//

import Foundation
import Combine

class SwellPredictionService: ObservableObject {
    static let shared = SwellPredictionService()
    
    @Published var predictions: [String: SwellPredictionEntry] = [:]
    @Published var multiplePredictions: [String: [SwellPredictionEntry]] = [:]
    @Published var isLoading: Bool = false
    @Published var lastError: Error?
    
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fetch swell prediction for a specific spot (handles both old and new DynamoDB format)
    func fetchSwellPrediction(for spot: SpotData, completion: @escaping (Result<[SwellPredictionEntry], Error>) -> Void) {
        let spotComponents = spot.id.components(separatedBy: "#")
        guard spotComponents.count == 3 else {
            completion(.failure(SwellPredictionError.invalidSpotId))
            return
        }
        
        let country = spotComponents[0]
        let region = spotComponents[1]
        let spotName = spotComponents[2]
        
        isLoading = true
        lastError = nil
        
        // Use regular format first (handles array responses), fallback to DynamoDB format
        apiClient.fetchSwellPrediction(country: country, region: region, spot: spotName) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let responses):
                    let entries = responses.map { SwellPredictionEntry(from: $0) }
                        .sorted { $0.arrivalTime < $1.arrivalTime }
                    // Store all predictions sorted by arrival time
                    self?.multiplePredictions[spot.id] = entries
                    // Store the first prediction as the primary one for backward compatibility
                    if let firstEntry = entries.first {
                        self?.predictions[spot.id] = firstEntry
                    }
                    completion(.success(entries))
                case .failure:
                    // Fallback to DynamoDB format
                    self?.apiClient.fetchSwellPredictionDynamoDB(country: country, region: region, spot: spotName) { [weak self] fallbackResult in
                        DispatchQueue.main.async {
                            switch fallbackResult {
                            case .success(let dynamoDBData):
                                let response = SwellPredictionResponse(from: dynamoDBData)
                                let entry = SwellPredictionEntry(from: response)
                                self?.predictions[spot.id] = entry
                                completion(.success([entry]))
                            case .failure(let fallbackError):
                                self?.lastError = fallbackError
                                completion(.failure(fallbackError))
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Parse DynamoDB format data and create SwellPredictionEntry
    func parseDynamoDBFormat(data: [String: DynamoDBAttributeValue], spotId: String) -> SwellPredictionEntry {
        let response = SwellPredictionResponse(from: data)
        return SwellPredictionEntry(from: response)
    }
    
    /// Fetch swell predictions for multiple spots in the same region
    func fetchMultipleSpotsSwellPrediction(for spots: [SpotData], completion: @escaping (Result<[SwellPredictionEntry], Error>) -> Void) {
        guard !spots.isEmpty else {
            completion(.success([]))
            return
        }
        
        // Group spots by region
        let regionGroups = Dictionary(grouping: spots) { spot in
            let components = spot.id.components(separatedBy: "#")
            return components.count >= 2 ? "\(components[0])#\(components[1])" : ""
        }
        
        var allPredictions: [SwellPredictionEntry] = []
        let group = DispatchGroup()
        var lastError: Error?
        
        for (regionKey, regionSpots) in regionGroups {
            guard !regionKey.isEmpty else { continue }
            
            let regionComponents = regionKey.components(separatedBy: "#")
            guard regionComponents.count == 2 else { continue }
            
            let country = regionComponents[0]
            let region = regionComponents[1]
            let spotNames = regionSpots.map { spot in
                spot.id.components(separatedBy: "#").last ?? ""
            }.filter { !$0.isEmpty }
            
            group.enter()
            apiClient.fetchMultipleSpotsSwellPrediction(country: country, region: region, spots: spotNames) { result in
                defer { group.leave() }
                
                switch result {
                case .success(let responses):
                    let entries = responses.flatMap { $0.map { SwellPredictionEntry(from: $0) } }
                    allPredictions.append(contentsOf: entries)
                case .failure(let error):
                    lastError = error
                }
            }
        }
        
        group.notify(queue: .main) {
            if let error = lastError {
                completion(.failure(error))
            } else {
                // Update local cache
                for entry in allPredictions {
                    self.predictions[entry.spotId] = entry
                }
                completion(.success(allPredictions))
            }
        }
    }
    
    /// Fetch swell predictions for all spots in a region
    func fetchRegionSwellPrediction(country: String, region: String, completion: @escaping (Result<[SwellPredictionEntry], Error>) -> Void) {
        isLoading = true
        lastError = nil
        
        apiClient.fetchRegionSwellPrediction(country: country, region: region) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let responses):
                    let entries = responses.map { SwellPredictionEntry(from: $0) }
                    // Update local cache
                    for entry in entries {
                        self?.predictions[entry.spotId] = entry
                    }
                    completion(.success(entries))
                case .failure(let error):
                    self?.lastError = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Fetch swell prediction range for a spot
    func fetchSwellPredictionRange(for spot: SpotData, startTime: Date, endTime: Date, completion: @escaping (Result<[SwellPredictionEntry], Error>) -> Void) {
        let spotComponents = spot.id.components(separatedBy: "#")
        guard spotComponents.count == 3 else {
            completion(.failure(SwellPredictionError.invalidSpotId))
            return
        }
        
        let country = spotComponents[0]
        let region = spotComponents[1]
        let spotName = spotComponents[2]
        
        isLoading = true
        lastError = nil
        
        apiClient.fetchSwellPredictionRange(country: country, region: region, spot: spotName, startTime: startTime, endTime: endTime) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let responses):
                    let entries = responses.map { SwellPredictionEntry(from: $0) }
                    completion(.success(entries))
                case .failure(let error):
                    self?.lastError = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Fetch recent swell predictions
    func fetchRecentSwellPredictions(hours: Int = 24, completion: @escaping (Result<[SwellPredictionEntry], Error>) -> Void) {
        isLoading = true
        lastError = nil
        
        apiClient.fetchRecentSwellPredictions(hours: hours) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let responses):
                    let entries = responses.map { SwellPredictionEntry(from: $0) }
                    // Update local cache
                    for entry in entries {
                        self?.predictions[entry.spotId] = entry
                    }
                    completion(.success(entries))
                case .failure(let error):
                    self?.lastError = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get cached prediction for a spot
    func getCachedPrediction(for spotId: String) -> SwellPredictionEntry? {
        return predictions[spotId]
    }
    
    /// Get all cached predictions for a spot
    func getCachedMultiplePredictions(for spotId: String) -> [SwellPredictionEntry]? {
        return multiplePredictions[spotId]
    }
    
    /// Clear cached predictions
    func clearCache() {
        predictions.removeAll()
        multiplePredictions.removeAll()
    }
    
    /// Clear cached prediction for a specific spot
    func clearCache(for spotId: String) {
        predictions.removeValue(forKey: spotId)
        multiplePredictions.removeValue(forKey: spotId)
    }
    
    /// Check if prediction is stale (older than 1 hour)
    func isPredictionStale(for spotId: String) -> Bool {
        guard let prediction = predictions[spotId] else { return true }
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return prediction.generatedAt < oneHourAgo
    }
    
    /// Refresh prediction if stale
    func refreshIfStale(for spot: SpotData, completion: @escaping (Result<SwellPredictionEntry?, Error>) -> Void) {
        if isPredictionStale(for: spot.id) {
            fetchSwellPrediction(for: spot) { result in
                switch result {
                case .success(let entries):
                    // Return the first prediction for backward compatibility
                    completion(.success(entries.first))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            completion(.success(getCachedPrediction(for: spot.id)))
        }
    }
}

// MARK: - Error Types

enum SwellPredictionError: Error, LocalizedError {
    case invalidSpotId
    case noDataAvailable
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidSpotId:
            return "Invalid spot ID format"
        case .noDataAvailable:
            return "No swell prediction data available"
        case .networkError:
            return "Network error occurred"
        }
    }
}

// MARK: - Convenience Extensions

extension SwellPredictionService {
    /// Get the best prediction for a spot (highest confidence)
    func getBestPrediction(for spotId: String) -> SwellPredictionEntry? {
        return predictions[spotId]
    }
    
    /// Get predictions sorted by confidence
    func getPredictionsSortedByConfidence() -> [SwellPredictionEntry] {
        return predictions.values.sorted { $0.confidence > $1.confidence }
    }
    
    /// Get predictions sorted by surf size
    func getPredictionsSortedBySurfSize() -> [SwellPredictionEntry] {
        return predictions.values.sorted { $0.surfSize > $1.surfSize }
    }
    
    /// Get predictions for spots with good conditions (surf size > 2m and confidence > 0.7)
    func getGoodConditionsPredictions() -> [SwellPredictionEntry] {
        return predictions.values.filter { 
            $0.surfSize > 2.0 && $0.confidence > 0.7 
        }.sorted { $0.surfSize > $1.surfSize }
    }
}
