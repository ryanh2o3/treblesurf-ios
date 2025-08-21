
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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Sticky header - always visible at the top
                ZStack {
                    if let spotImage = spotImage {
                        spotImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                    }
                    
                    // Overlay with swell direction arrow and key data
                    VStack {
                        Spacer()
                        
                        // Key data display
                        if let entry = currentForecastEntry {
                            VStack(spacing: 8) {
                                HStack(spacing: 16) {
                                    VStack(spacing: 4) {
                                        Text("Swell")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Text("\(entry.swellHeight, specifier: "%.1f")m")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("Wind")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Text("\(Int(entry.windSpeed * 3.6)) km/h")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("Temp")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Text("\(Int(entry.temperature))°C")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Swell direction arrow
                        Image(systemName: "arrow.down")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(Angle(degrees: currentForecastEntry?.swellDirection ?? dataStore.currentConditions.swellDirection))
                            .animation(.default, value: currentForecastEntry?.swellDirection)
                            .padding(.bottom, 16)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                
                // Mode toggle buttons - also part of sticky header
                HStack {
                    ForEach(ForecastViewMode.allCases) { mode in
                        Button(action: {
                            viewModel.setViewMode(mode)
                        }) {
                            Text(mode.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(viewModel.selectedMode == mode ? Color.blue : Color(.systemGray5))
                                )
                                .foregroundColor(viewModel.selectedMode == mode ? .white : .primary)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 6)
                .padding(.bottom, 16)
                
                // Fixed height scrollable content area - creates natural scroll boundary
                ScrollView {
                    VStack(spacing: 16) {
                        SurfTableView(entries: viewModel.filteredEntries, selectedEntry: currentForecastEntry) { visibleEntry in
                            currentForecastEntry = visibleEntry
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Table toggle indicators
                        HStack(spacing: 8) {
                            ForEach(0..<2) { index in
                                Circle()
                                    .fill(selectedTable == index ? Color.blue : Color.gray.opacity(0.5))
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
                    .padding(.bottom, 20) // Add bottom padding for content
                }
                .frame(height: geometry.size.height - 280) // Fixed height: screen height minus header height
            }
        }
        .frame(height: UIScreen.main.bounds.height) // Force full screen height to create scroll boundary
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            viewModel.fetchForecast(for: spotId) { success in
                if !success {
                    print("Failed to fetch conditions for spot: \(spotId)")
                }
                // Set the first entry as selected when forecast loads
                DispatchQueue.main.async {
                    if let firstEntry = viewModel.filteredEntries.first {
                        currentForecastEntry = firstEntry
                    }
                }
            }
            dataStore.fetchSpotImage(for: spotId) { image in
                self.spotImage = image
            }
        }
        .onChange(of: viewModel.filteredEntries) { entries in
            // Update selection when entries change
            if currentForecastEntry == nil, let firstEntry = entries.first {
                currentForecastEntry = firstEntry
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
