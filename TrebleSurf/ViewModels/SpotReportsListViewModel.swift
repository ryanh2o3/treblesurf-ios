import Foundation
import SwiftUI

@MainActor
class SpotReportsListViewModel: ObservableObject {
    @Published var reports: [SurfReport] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?
    
    private let spotId: String
    private let reportsPerPage = 20
    private var currentPage = 0
    
    init(spotId: String) {
        self.spotId = spotId
    }
    
    func loadInitialReports() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        currentPage = 0
        
        fetchReports()
    }
    
    func loadMoreReports() {
        guard !isLoadingMore && hasMore else { return }
        
        isLoadingMore = true
        errorMessage = nil
        currentPage += 1
        
        fetchReports()
    }
    
    func refresh() async {
        await MainActor.run {
            reports = []
            currentPage = 0
            hasMore = true
        }
        loadInitialReports()
    }
    
    private func fetchReports() {
        // Parse spotId into country, region, spot
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            errorMessage = "Invalid spot ID"
            isLoading = false
            isLoadingMore = false
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        // Calculate the total limit (fetch all reports up to current page)
        let limit = (currentPage + 1) * reportsPerPage
        
        APIClient.shared.fetchAllSpotReports(
            country: country,
            region: region,
            spot: spot,
            limit: limit
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                self.isLoadingMore = false
                
                switch result {
                case .success(let responses):
                    // Convert responses to SurfReport objects
                    let newReports = responses.map { SurfReport(from: $0) }
                    
                    // Check if we have more reports
                    // If we got fewer reports than requested, there are no more
                    self.hasMore = newReports.count >= limit
                    
                    // Replace all reports (since we're fetching from the beginning each time)
                    self.reports = newReports
                    
                    print("📋 Loaded \(newReports.count) reports, hasMore: \(self.hasMore)")
                    
                case .failure(let error):
                    self.errorMessage = "Failed to load reports: \(error.localizedDescription)"
                    print("❌ Failed to fetch reports: \(error)")
                }
            }
        }
    }
}

