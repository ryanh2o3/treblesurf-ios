import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var currentCondition: CurrentCondition?
    @Published var featuredSpots: [FeaturedSpot] = []
    @Published var recentReports: [SurfReport] = []
    
    var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    init() {
        // Initial setup
    }
    
    func loadData() {
        // Placeholder for data loading
        loadMockData()
        fetchSurfReports()
    }
    
    private func fetchSurfReports() {
            APIClient.shared.fetchSurfReports(country: "Ireland", region: "Donegal", spot: "Ballymastocker") { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let responses):
                        let inputDateFormatter = DateFormatter()
                                        inputDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ 'UTC'" // Adjust to match the input format
                                        inputDateFormatter.locale = Locale(identifier: "en_US_POSIX")

                                        let outputDateFormatter = DateFormatter()
                                        outputDateFormatter.dateFormat = "d MMM, h:mma"
                                        outputDateFormatter.locale = Locale(identifier: "en_US_POSIX")

                                        self?.recentReports = responses.map { response in
                                            let date: Date? = inputDateFormatter.date(from: response.time)
                                            let formattedTime = date != nil ? outputDateFormatter.string(from: date!) : "Invalid Date"
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
                                countryRegionSpot: response.countryRegionSpot,
                                dateReported: response.dateReported
                            )
                            
                            if !response.imageKey.isEmpty {
                                self?.fetchImage(for: response.imageKey) { imageData in
                                    DispatchQueue.main.async {
                                        report.imageData = imageData?.imageData
                                        self?.objectWillChange.send() // Notify UI of changes
                                    }
                                }
                            }
                            
                            return report
                        }
                    case .failure(let error):
                        print("Failed to fetch surf reports: \(error.localizedDescription)")
                    }
                }
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
