// SpotsViewModel.swift
// SpotsViewModel.swift
import Foundation
import SwiftUI

@MainActor
class SpotsViewModel: ObservableObject {
    @Published var spots: [SpotData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var dataStore: DataStore = DataStore()

    func setDataStore(_ store: DataStore) {
            dataStore = store
        }
    
    func loadSpots() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await withCheckedThrowingContinuation { continuation in
                dataStore.fetchRegionSpots(region: "Donegal") { [weak self] result in
                    switch result {
                    case .success(let spots):
                        Task { @MainActor in
                            self?.spots = spots
                            self?.isLoading = false
                        }
                        continuation.resume()
                    case .failure(let error):
                        Task { @MainActor in
                            self?.errorMessage = error.localizedDescription
                            self?.isLoading = false
                        }
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            // Error already handled in the continuation
        }
    }
    
    // Helper method to get sorted spot names
    var spotNames: [String] {
        return spots.map { $0.name }.sorted()
    }
}
