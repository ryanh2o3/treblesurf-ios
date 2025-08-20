
// SpotForecastView.swift
import SwiftUI
import Charts


struct SpotForecastView: View {
    @StateObject private var viewModel: SpotForecastViewModel
        @EnvironmentObject var dataStore: DataStore
        var spotId: String
        @State private var spotImage: Image? = nil
        @State private var selectedTable = 0 // 0 = surf/wind, 1 = weather
        @State private var currentForecastEntry: ForecastEntry? = nil
        
    
    init(spotId: String) {
        self.spotId = spotId
        _viewModel = StateObject(wrappedValue: SpotForecastViewModel(dataStore: DataStore.shared))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                        if let spotImage = spotImage {
                            spotImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        }
                        
                Image(systemName: "arrow.down")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.blue)
                                    .rotationEffect(Angle(degrees: currentForecastEntry?.swellDirection ?? dataStore.currentConditions.swellDirection))
                                    .animation(.default, value: currentForecastEntry?.swellDirection)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
            // Mode toggle buttons
            HStack {
                ForEach(ForecastViewMode.allCases) { mode in
                    Button(action: {
                        viewModel.setViewMode(mode)
                    }) {
                        Text(mode.rawValue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                            .background(viewModel.selectedMode == mode ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundColor(viewModel.selectedMode == mode ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            ScrollView {
                SurfTableView(entries: viewModel.filteredEntries) { visibleEntry in
                    print("Entry became visible: \(visibleEntry.dateForecastedFor)")
                    currentForecastEntry = visibleEntry
                }
                .frame(width: UIScreen.main.bounds.width)
                
                
                // Table toggle indicators
                HStack(spacing: 8) {
                    ForEach(0..<2) { index in
                        Circle()
                            .fill(selectedTable == index ? Color.gray : Color.secondary)
                            .frame(width: 8, height: 8)
                            .onTapGesture {
                                withAnimation {
                                    selectedTable = index
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
        .onAppear {
            viewModel.fetchForecast(for: spotId) { success in
                if !success {
                    print("Failed to fetch conditions for spot: \(spotId)")
                }
                let firstEntry = viewModel.filteredEntries.first
                currentForecastEntry = firstEntry
                
            }
            dataStore.fetchSpotImage(for: spotId) { image in
                self.spotImage = image
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }
}



struct TidePoint: Identifiable {
    let id: UUID
    let time: Date
    let height: Double
    let isHighTide: Bool
}

struct TideChartView: View {
    let tideData: [TidePoint]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Tide").font(.headline)
            
            Chart {
                ForEach(tideData) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Height", point.height)
                    )
                    .foregroundStyle(Color.green)
                    
                    if point.isHighTide {
                        PointMark(
                            x: .value("Time", point.time),
                            y: .value("Height", point.height)
                        )
                        .foregroundStyle(Color.green)
                        .annotation {
                            Text("\(point.height, specifier: "%.1f")m")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
}
