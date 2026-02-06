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
    @MainActor
    func fetchSwellPrediction(for spot: SpotData) async throws -> [SwellPredictionEntry] {
        let spotComponents = spot.id.components(separatedBy: "#")
        guard spotComponents.count == 3 else {
            throw SwellPredictionError.invalidSpotId
        }

        let country = spotComponents[0]
        let region = spotComponents[1]
        let spotName = spotComponents[2]

        isLoading = true
        lastError = nil

        do {
            let responses = try await apiClient.fetchSwellPrediction(country: country, region: region, spot: spotName)
            let entries = responses.map { SwellPredictionEntry(from: $0) }
                .sorted { $0.arrivalTime < $1.arrivalTime }
            isLoading = false
            multiplePredictions[spot.id] = entries
            if let firstEntry = entries.first {
                predictions[spot.id] = firstEntry
            }
            return entries
        } catch {
            // Fallback to DynamoDB format
            do {
                let dynamoDBData = try await apiClient.fetchSwellPredictionDynamoDB(country: country, region: region, spot: spotName)
                let response = SwellPredictionResponse(from: dynamoDBData)
                let entry = SwellPredictionEntry(from: response)
                isLoading = false
                predictions[spot.id] = entry
                return [entry]
            } catch {
                isLoading = false
                lastError = error
                throw error
            }
        }
    }

    /// Parse DynamoDB format data and create SwellPredictionEntry
    func parseDynamoDBFormat(data: [String: DynamoDBAttributeValue], spotId: String) -> SwellPredictionEntry {
        let response = SwellPredictionResponse(from: data)
        return SwellPredictionEntry(from: response)
    }

    /// Fetch swell predictions for multiple spots in the same region
    @MainActor
    func fetchMultipleSpotsSwellPrediction(for spots: [SpotData]) async throws -> [SwellPredictionEntry] {
        guard !spots.isEmpty else {
            return []
        }

        // Group spots by region
        let regionGroups = Dictionary(grouping: spots) { spot in
            let components = spot.id.components(separatedBy: "#")
            return components.count >= 2 ? "\(components[0])#\(components[1])" : ""
        }

        var allPredictions: [SwellPredictionEntry] = []
        var lastEncounteredError: Error?

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
                let responses = try await apiClient.fetchMultipleSpotsSwellPrediction(country: country, region: region, spots: spotNames)
                let entries = responses.flatMap { $0.map { SwellPredictionEntry(from: $0) } }
                allPredictions.append(contentsOf: entries)
            } catch {
                lastEncounteredError = error
            }
        }

        if let error = lastEncounteredError, allPredictions.isEmpty {
            self.lastError = error
            throw error
        }

        for entry in allPredictions {
            predictions[entry.spotId] = entry
        }
        return allPredictions
    }

    /// Fetch swell predictions for all spots in a region
    @MainActor
    func fetchRegionSwellPrediction(country: String, region: String) async throws -> [SwellPredictionEntry] {
        isLoading = true
        lastError = nil
        do {
            let responses = try await apiClient.fetchRegionSwellPrediction(country: country, region: region)
            let entries = responses.map { SwellPredictionEntry(from: $0) }
            isLoading = false
            for entry in entries {
                predictions[entry.spotId] = entry
            }
            return entries
        } catch {
            isLoading = false
            lastError = error
            throw error
        }
    }

    /// Fetch swell prediction range for a spot
    @MainActor
    func fetchSwellPredictionRange(for spot: SpotData, startTime: Date, endTime: Date) async throws -> [SwellPredictionEntry] {
        let spotComponents = spot.id.components(separatedBy: "#")
        guard spotComponents.count == 3 else {
            throw SwellPredictionError.invalidSpotId
        }

        let country = spotComponents[0]
        let region = spotComponents[1]
        let spotName = spotComponents[2]

        isLoading = true
        lastError = nil

        do {
            let responses = try await apiClient.fetchSwellPredictionRange(country: country, region: region, spot: spotName, startTime: startTime, endTime: endTime)
            let entries = responses.map { SwellPredictionEntry(from: $0) }
            isLoading = false
            return entries
        } catch {
            isLoading = false
            lastError = error
            throw error
        }
    }

    /// Fetch recent swell predictions
    @MainActor
    func fetchRecentSwellPredictions(hours: Int = 24) async throws -> [SwellPredictionEntry] {
        isLoading = true
        lastError = nil
        do {
            let responses = try await apiClient.fetchRecentSwellPredictions(hours: hours)
            let entries = responses.map { SwellPredictionEntry(from: $0) }
            isLoading = false
            for entry in entries {
                predictions[entry.spotId] = entry
            }
            return entries
        } catch {
            isLoading = false
            lastError = error
            throw error
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
    @MainActor
    func refreshIfStale(for spot: SpotData) async throws -> SwellPredictionEntry? {
        if isPredictionStale(for: spot.id) {
            let entries = try await fetchSwellPrediction(for: spot)
            return entries.first
        } else {
            return getCachedPrediction(for: spot.id)
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
