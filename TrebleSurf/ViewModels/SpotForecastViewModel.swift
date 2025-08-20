import SwiftUI
import Combine

enum ForecastViewMode: String, CaseIterable, Identifiable {
    case hourly = "Hourly"
    case multiHour = "Multi-hour"
    case daily = "Daily"
    
    var id: String { self.rawValue }
}

class SpotForecastViewModel: ObservableObject {
    @Published var selectedMode: ForecastViewMode = .hourly
    @Published var filteredEntries: [ForecastEntry] = []
    
    private var dataStore: DataStore
    private var cancellables = Set<AnyCancellable>()
    
    init(dataStore: DataStore) {
        self.dataStore = dataStore
        
        // Observe changes to currentForecastEntries
        dataStore.$currentForecastEntries
            .sink { [weak self] entries in
                self?.updateFilteredEntries(entries: entries)
            }
            .store(in: &cancellables)
    }
    
    func setViewMode(_ mode: ForecastViewMode) {
        selectedMode = mode
        updateFilteredEntries(entries: dataStore.currentForecastEntries)
    }
    
    private func updateFilteredEntries(entries: [ForecastEntry]) {
        switch selectedMode {
        case .hourly:
            // Show all hourly data
            filteredEntries = entries
            
        case .multiHour:
            // Show data every 3 hours
            let calendar = Calendar.current
            filteredEntries = entries.filter { entry in
                let hour = calendar.component(.hour, from: entry.dateForecastedFor)
                return hour % 3 == 0
            }
            
        case .daily:
            // Show one entry per day (at noon)
            let calendar = Calendar.current
            var dailyEntries: [Date: ForecastEntry] = [:]
            
            for entry in entries {
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: entry.dateForecastedFor)
                if let date = calendar.date(from: dateComponents) {
                    if dailyEntries[date] == nil {
                        dailyEntries[date] = entry
                    } else {
                        let hour = calendar.component(.hour, from: entry.dateForecastedFor)
                        let existingHour = calendar.component(.hour, from: dailyEntries[date]!.dateForecastedFor)
                        
                        if abs(hour - 12) < abs(existingHour - 12) {
                            // Use entry closer to noon
                            dailyEntries[date] = entry
                        }
                    }
                }
            }
            
            filteredEntries = dailyEntries.values.sorted { $0.dateForecastedFor < $1.dateForecastedFor }
        }
    }
    
    func fetchForecast(for spotId: String, completion: @escaping (Bool) -> Void) {
        dataStore.fetchForecast(for: spotId, completion: completion)
    }
}
