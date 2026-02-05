//
//  SwellPredictionService.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 01/01/2025.
//

import Foundation
import Combine

class SwellPredictionService: ObservableObject {
    @Published var predictions: [String: SwellPredictionEntry] = [:]
    @Published var multiplePredictions: [String: [SwellPredictionEntry]] = [:]
    @Published var isLoading: Bool = false
    @Published var lastError: Error?
    
    private let apiClient: APIClient
    private var cancellables = Set<AnyCancellable>()
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
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
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let responses = try await self.apiClient.fetchSwellPrediction(country: country, region: region, spot: spotName)
                let entries = responses.map { SwellPredictionEntry(from: $0) }
                    .sorted { $0.arrivalTime < $1.arrivalTime }
                self.isLoading = false
                self.multiplePredictions[spot.id] = entries
                if let firstEntry = entries.first {
                    self.predictions[spot.id] = firstEntry
                }
                completion(.success(entries))
            } catch {
                // Fallback to DynamoDB format
                do {
                    let dynamoDBData = try await self.apiClient.fetchSwellPredictionDynamoDB(country: country, region: region, spot: spotName)
                    let response = SwellPredictionResponse(from: dynamoDBData)
                    let entry = SwellPredictionEntry(from: response)
                    self.isLoading = false
                    self.predictions[spot.id] = entry
                    completion(.success([entry]))
                } catch {
                    self.isLoading = false
                    self.lastError = error
                    completion(.failure(error))
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
        
        Task { [weak self] in
            guard let self = self else { return }
            var allPredictions: [SwellPredictionEntry] = []
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
                
                do {
                    let responses = try await self.apiClient.fetchMultipleSpotsSwellPrediction(country: country, region: region, spots: spotNames)
                    let entries = responses.flatMap { $0.map { SwellPredictionEntry(from: $0) } }
                    allPredictions.append(contentsOf: entries)
                } catch {
                    lastError = error
                }
            }
            
            if let error = lastError {
                await MainActor.run {
                    self.lastError = error
                    completion(.failure(error))
                }
            } else {
                await MainActor.run {
                    for entry in allPredictions {
                        self.predictions[entry.spotId] = entry
                    }
                    completion(.success(allPredictions))
                }
            }
        }
    }
    
    /// Fetch swell predictions for all spots in a region
    func fetchRegionSwellPrediction(country: String, region: String, completion: @escaping (Result<[SwellPredictionEntry], Error>) -> Void) {
        isLoading = true
        lastError = nil
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let responses = try await self.apiClient.fetchRegionSwellPrediction(country: country, region: region)
                let entries = responses.map { SwellPredictionEntry(from: $0) }
                await MainActor.run {
                    self.isLoading = false
                    for entry in entries {
                        self.predictions[entry.spotId] = entry
                    }
                    completion(.success(entries))
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.lastError = error
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
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let responses = try await self.apiClient.fetchSwellPredictionRange(country: country, region: region, spot: spotName, startTime: startTime, endTime: endTime)
                let entries = responses.map { SwellPredictionEntry(from: $0) }
                await MainActor.run {
                    self.isLoading = false
                    completion(.success(entries))
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.lastError = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Fetch recent swell predictions
    func fetchRecentSwellPredictions(hours: Int = 24, completion: @escaping (Result<[SwellPredictionEntry], Error>) -> Void) {
        isLoading = true
        lastError = nil
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let responses = try await self.apiClient.fetchRecentSwellPredictions(hours: hours)
                let entries = responses.map { SwellPredictionEntry(from: $0) }
                await MainActor.run {
                    self.isLoading = false
                    for entry in entries {
                        self.predictions[entry.spotId] = entry
                    }
                    completion(.success(entries))
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.lastError = error
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
