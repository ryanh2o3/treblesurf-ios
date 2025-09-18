import Foundation
import Combine

// MARK: - Buoy Cache Service
class BuoyCacheService: ObservableObject {
    static let shared = BuoyCacheService()
    
    @Published var cachedBuoyData: [String: BuoyResponse] = [:]
    @Published var lastFetchTime: Date?
    
    private let cacheExpirationInterval: TimeInterval = 5 * 60 // 5 minutes
    private let cacheQueue = DispatchQueue(label: "com.treblesurf.buoycache", qos: .utility)
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get cached buoy data for specific buoy names
    func getCachedBuoyData(for buoyNames: [String]) -> [BuoyResponse]? {
        guard !isCacheExpired else { return nil }
        
        let availableBuoys = buoyNames.compactMap { name in
            cachedBuoyData[name]
        }
        
        return availableBuoys.count == buoyNames.count ? availableBuoys : nil
    }
    
    /// Cache buoy data
    func cacheBuoyData(_ responses: [BuoyResponse]) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                for response in responses {
                    self.cachedBuoyData[response.name] = response
                }
                self.lastFetchTime = Date()
            }
        }
    }
    
    /// Check if cache is expired
    var isCacheExpired: Bool {
        guard let lastFetch = lastFetchTime else { return true }
        return Date().timeIntervalSince(lastFetch) > cacheExpirationInterval
    }
    
    /// Clear cache
    func clearCache() {
        cacheQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.cachedBuoyData.removeAll()
                self?.lastFetchTime = nil
            }
        }
    }
    
    /// Get specific buoy data by name
    func getBuoyData(for name: String) -> BuoyResponse? {
        return cachedBuoyData[name]
    }
    
    /// Check if specific buoy data is available
    func hasBuoyData(for name: String) -> Bool {
        return cachedBuoyData[name] != nil
    }
}
