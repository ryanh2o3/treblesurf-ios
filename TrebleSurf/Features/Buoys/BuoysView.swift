import SwiftUI
import Charts

struct BuoysView: View {
    @StateObject private var viewModel = BuoysViewModel()
    @State private var selectedBuoy: Buoy?
    
    var body: some View {
        NavigationView {
            MainLayout {
                VStack(spacing: 16) {
                    // Header with title and theme toggle
                    HStack {
                        Text("Buoys")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        ThemeToggleButton()
                    }
                    .padding(.horizontal)
                    
                    // Buoy list or details
                    if let selectedBuoy = selectedBuoy {
                        buoyDetailView(selectedBuoy)
                    } else {
                        buoyListView
                    }
                }
                .padding()
                .task {
                    await viewModel.loadBuoys()
                }
            }
            .navigationBarHidden(true)

        }
    }
    

    
//    private var buoyFilter: some View {
//        HStack {
//            Text("Filter by:")
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//            
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 8) {
//                    filterButton("All", tag: nil)
//                    filterButton("NOAA", tag: "NOAA")
//                    filterButton("CDIP", tag: "CDIP")
//                    filterButton("Nearby", tag: "Nearby")
//                }
//            }
//        }
//    }
    
//    private func filterButton(_ title: String, tag: String?) -> some View {
//        Button {
//            viewModel.selectedFilter = tag
//        } label: {
//            Text(title)
//                .font(.subheadline)
//                .padding(.horizontal, 12)
//                .padding(.vertical, 6)
//                .background(
//                    viewModel.selectedFilter == tag ?
//                    Color.blue.opacity(0.8) :
//                    Color.gray.opacity(0.2)
//                )
//                .foregroundColor(
//                    viewModel.selectedFilter == tag ?
//                    .white : .primary
//                )
//                .cornerRadius(20)
//        }
//    }
    
    private var buoyListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.filteredBuoys) { buoy in
                    BuoyCard(buoy: buoy)
                        .onTapGesture {
                            selectedBuoy = buoy
                        }
                }
            }
        }
    }
    
    private func buoyDetailView(_ buoy: Buoy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Back button
                Button {
                    selectedBuoy = nil
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back to Buoys")
                    }
                    .foregroundColor(.blue)
                }
                
                // Buoy info
                VStack(alignment: .leading, spacing: 12) {
                    Text(buoy.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Station \(buoy.stationId) • \(buoy.organization)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Last updated: \(buoy.lastUpdated)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Current readings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Readings")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ReadingCard(title: "Wave Height", value: buoy.waveHeight, unit: "m", icon: "water.waves")
                        ReadingCard(title: "Period", value: buoy.maxPeriod, unit: "sec", icon: "timer")
                        ReadingCard(title: "Wind Speed", value: buoy.windSpeed, unit: "km/h", icon: "wind")
                        ReadingCard(title: "Direction", value: buoy.waveDirection, unit: "°", icon: "arrow.up.right")
                        ReadingCard(title: "Water Temp", value: buoy.waterTemp, unit: "°C", icon: "thermometer")
                        ReadingCard(title: "Air Temp", value: buoy.airTemp, unit: "°C", icon: "thermometer.sun")
                    }
                }
                
                // Wave height chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Wave Height (24h)")
                        .font(.headline)
                    
                    if #available(iOS 16.0, *) {
                        Chart(buoy.historicalData) { dataPoint in
                            LineMark(
                                x: .value("Time", dataPoint.time),
                                y: .value("Wave Height", dataPoint.waveHeight)
                            )
                            .foregroundStyle(Color.blue)
                            
                            AreaMark(
                                x: .value("Time", dataPoint.time),
                                y: .value("Wave Height", dataPoint.waveHeight)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        .frame(height: 200)
                        .chartYScale(domain: 0...(buoy.maxWaveHeight + 1))
                    } else {
                        // Fallback for iOS < 16
                        Text("Chart requires iOS 16 or later")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Additional information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Buoy Information")
                        .font(.headline)
                    
                    Text("Location: \(buoy.latitude), \(buoy.longitude)")
                    Text("Distance to shore: \(buoy.distanceToShore) nautical miles")
                    Text("Depth: \(buoy.depth)")
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadHistoricalDataForBuoy(id: buoy.id) { updatedBuoy in
                        selectedBuoy = updatedBuoy
                    }
                }
            }
        }
    }
}

struct BuoyCard: View {
    let buoy: Buoy
    
    var body: some View {
        HStack(spacing: 12) {
            // Buoy icon with organization indicator
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "water.waves")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                
                Text(buoy.organization.prefix(1))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .offset(x: 16, y: -16)
            }
            
            // Buoy information
            VStack(alignment: .leading, spacing: 4) {
                Text(buoy.name)
                    .font(.headline)
                
                Text("Station \(buoy.stationId)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Label {
                        Text("\(buoy.waveHeight) m")
                    } icon: {
                        Image(systemName: "water.waves")
                            .foregroundColor(.blue)
                    }
                    .font(.caption)
                    
                    Label {
                        Text("\(buoy.maxPeriod) sec")
                    } icon: {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                    }
                    .font(.caption)
                }
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ReadingCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
