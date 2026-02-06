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
    private let surfReportService: SurfReportService
    private let logger: ErrorLoggerProtocol
    private let reportsPerPage = 20
    private var currentPage = 0

    init(spotId: String, surfReportService: SurfReportService, logger: ErrorLoggerProtocol? = nil) {
        self.spotId = spotId
        self.surfReportService = surfReportService
        self.logger = logger ?? ErrorLogger(minimumLogLevel: .info, enableConsoleOutput: true, enableOSLog: true)
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
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                // SurfReportService returns domain models already
                let newReports = try await surfReportService.fetchAllSpotReports(
                    country: country,
                    region: region,
                    spot: spot,
                    limit: limit
                )
                
                self.isLoading = false
                self.isLoadingMore = false
                
                // Check if we have more reports
                // If we got fewer reports than requested, there are no more
                self.hasMore = newReports.count >= limit
                
                // Replace all reports (since we're fetching from the beginning each time)
                self.reports = newReports
                
                self.logger.log("Loaded \(newReports.count) reports, hasMore: \(self.hasMore)", level: .info, category: .api)
            } catch {
                self.isLoading = false
                self.isLoadingMore = false
                self.errorMessage = "Failed to load reports: \(error.localizedDescription)"
                self.logger.log("Failed to fetch reports: \(error)", level: .error, category: .api)
            }
        }
    }
}

