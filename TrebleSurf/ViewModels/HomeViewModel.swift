import Foundation
import Combine

// MARK: - Cache Models
struct CachedSurfReports {
    let reports: [SurfReport]
    let timestamp: Date
    let country: String
    let region: String
    
    var isExpired: Bool {
        // Cache expires after 15 minutes
        return Date().timeIntervalSince(timestamp) > 15 * 60
    }
}

class HomeViewModel: ObservableObject {
    @Published var currentCondition: CurrentCondition?
    @Published var featuredSpots: [FeaturedSpot] = []
    @Published var recentReports: [SurfReport] = []
    
    // MARK: - Caching Properties
    private var surfReportsCache: [String: CachedSurfReports] = [:]
    private let cacheQueue = DispatchQueue(label: "com.treblesurf.cache", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    init() {
        // Initial setup
        setupCacheCleanup()
    }
    
    // MARK: - Cache Management
    private func setupCacheCleanup() {
        // Clean up expired cache entries every 5 minutes
        Timer.publish(every: 5 * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cleanupExpiredCache()
            }
            .store(in: &cancellables)
    }
    
    private func cleanupExpiredCache() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            let expiredKeys = self.surfReportsCache.keys.filter { key in
                self.surfReportsCache[key]?.isExpired == true
            }
            
            for key in expiredKeys {
                self.surfReportsCache.removeValue(forKey: key)
            }
            
            if !expiredKeys.isEmpty {
                print("Cache cleanup: Removed \(expiredKeys.count) expired entries")
            }
        }
    }
    
    private func getCacheKey(country: String, region: String) -> String {
        return "\(country)_\(region)"
    }
    
    private func getCachedReports(country: String, region: String) -> [SurfReport]? {
        let cacheKey = getCacheKey(country: country, region: region)
        guard let cached = surfReportsCache[cacheKey], !cached.isExpired else {
            return nil
        }
        
        print("Cache hit: Using cached surf reports for \(country)/\(region)")
        return cached.reports
    }
    
    private func cacheReports(_ reports: [SurfReport], country: String, region: String) {
        let cacheKey = getCacheKey(country: country, region: region)
        let cached = CachedSurfReports(
            reports: reports,
            timestamp: Date(),
            country: country,
            region: region
        )
        
        cacheQueue.async { [weak self] in
            self?.surfReportsCache[cacheKey] = cached
            print("Cache updated: Stored \(reports.count) surf reports for \(country)/\(region)")
        }
    }
    
    // MARK: - Public Methods
    func loadData() {
        // Placeholder for data loading
        loadMockData()
        fetchSurfReports()
    }
    
    func refreshSurfReports() {
        // Force refresh by clearing cache and fetching again
        let cacheKey = getCacheKey(country: "Ireland", region: "Donegal")
        surfReportsCache.removeValue(forKey: cacheKey)
        fetchSurfReports()
    }
    
    // MARK: - Private Methods
    private func fetchSurfReports() {
        // Check cache first
        if let cachedReports = getCachedReports(country: "Ireland", region: "Donegal") {
            DispatchQueue.main.async { [weak self] in
                self?.recentReports = cachedReports
            }
            return
        }
        
        // First fetch all spots, then get reports for each spot
        APIClient.shared.fetchSpots(country: "Ireland", region: "Donegal") { [weak self] result in
            switch result {
            case .success(let spots):
                // Fetch reports for each spot
                self?.fetchReportsForAllSpots(spots: spots)
            case .failure(let error):
                print("Failed to fetch spots: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchReportsForAllSpots(spots: [SpotData]) {
        var allReports: [SurfReport] = []
        let group = DispatchGroup()
        
        for spot in spots {
            group.enter()
            APIClient.shared.fetchSurfReports(country: "Ireland", region: "Donegal", spot: spot.name) { [weak self] result in
                defer { group.leave() }
                
                switch result {
                case .success(let responses):
                    let outputDateFormatter = DateFormatter()
                    outputDateFormatter.dateFormat = "d MMM, h:mma"
                    outputDateFormatter.locale = Locale(identifier: "en_US_POSIX")

                    let spotReports = responses.map { [weak self] response in
                        // Parse the timestamp with multiple format support
                        let date = self?.parseTimestamp(response.time)
                        let formattedTime = date != nil ? outputDateFormatter.string(from: date!) : "Invalid Date"
                        // Extract just the spot name from countryRegionSpot
                        let spotName = response.countryRegionSpot.components(separatedBy: "_").last ?? response.countryRegionSpot
                        
                        var report = SurfReport(
                            consistency: response.consistency,
                            imageKey: response.imageKey,
                            messiness: response.messiness,
                            quality: response.quality,
                            reporter: response.reporter,
                            surfSize: response.surfSize,
                            time: formattedTime,
                            userEmail: response.userEmail,
                            windAmount: response.windAmount,
                            windDirection: response.windDirection,
                            countryRegionSpot: spotName, // Now just the spot name
                            dateReported: response.dateReported
                        )
                        
                        if let imageKey = response.imageKey, !imageKey.isEmpty {
                            // Debug: print the imageKey to see its format
                            print("Debug - ImageKey from API: '\(imageKey)'")
                            // Use the imageKey directly as it should already contain the full path
                            self?.fetchImage(for: imageKey) { imageData in
                                DispatchQueue.main.async {
                                    report.imageData = imageData?.imageData
                                    self?.objectWillChange.send() // Notify UI of changes
                                }
                            }
                        }
                        
                        return report
                    }
                    
                    allReports.append(contentsOf: spotReports)
                    
                case .failure(let error):
                    print("Failed to fetch surf reports for spot \(spot.name): \(error.localizedDescription)")
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            self.recentReports = allReports
            
            // Cache the results
            self.cacheReports(allReports, country: "Ireland", region: "Donegal")
        }
    }
        
    private func fetchImage(for key: String, completion: @escaping (SurfReportImageResponse?) -> Void) {
            APIClient.shared.getReportImage(key: key) { result in
                switch result {
                case .success(let imageData):
                    completion(imageData)
                case .failure(let error):
                    print("Failed to fetch image for key \(key): \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    
    // Parse timestamp with multiple format support
    private func parseTimestamp(_ timestamp: String) -> Date? {
        // Try multiple date formats to handle different timestamp formats
        
        // Format 1: "2025-07-12 19:57:27 +0000 UTC"
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ 'UTC'"
        formatter1.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = formatter1.date(from: timestamp) {
            return date
        }
        
        // Format 2: "2025-08-18 22:32:30.819091968 +0000 UTC m=+293.995127367"
        // Extract the main timestamp part before the Go runtime info
        if timestamp.contains(" m=") {
            let components = timestamp.components(separatedBy: " m=")
            if let mainTimestamp = components.first {
                let formatter2 = DateFormatter()
                formatter2.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSSSS ZZZZZ 'UTC'"
                formatter2.locale = Locale(identifier: "en_US_POSIX")
                
                if let date = formatter2.date(from: mainTimestamp) {
                    return date
                }
                
                // Try without microseconds
                let formatter3 = DateFormatter()
                formatter3.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ 'UTC'"
                formatter3.locale = Locale(identifier: "en_US_POSIX")
                
                if let date = formatter3.date(from: mainTimestamp) {
                    return date
                }
            }
        }
        
        // Format 3: Try ISO8601 format
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: timestamp) {
            return date
        }
        
        // Format 4: Try parsing as a Date object directly (for debugging)
        print("Failed to parse timestamp: \(timestamp)")
        return nil
    }
    
    private func loadMockData() {
        // Load sample data
        currentCondition = CurrentCondition(
            waveHeight: "2-3ft",
            windDirection: "W",
            windSpeed: "5mph",
            temperature: "68°F",
            summary: "Mild conditions"
        )
        
        featuredSpots = [
            FeaturedSpot(
                id: "1",
                name: "Sample Beach",
                imageURL: nil,
                waveHeight: "3ft",
                quality: "Good",
                distance: "5 mi"
            )
        ]
        
    }
}

// Basic model structures
struct CurrentCondition {
    let waveHeight: String
    let windDirection: String
    let windSpeed: String
    let temperature: String
    let summary: String
}

struct FeaturedSpot: Identifiable {
    let id: String
    let name: String
    let imageURL: URL?
    let waveHeight: String
    let quality: String
    let distance: String
}
