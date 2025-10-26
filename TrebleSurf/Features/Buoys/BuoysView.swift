import SwiftUI
import Charts

struct BuoysView: View {
    @StateObject private var viewModel = BuoysViewModel()
    @State private var selectedBuoy: Buoy?
    
    var body: some View {
        NavigationStack {
            MainLayout {
            VStack(spacing: 16) {
                    
                    // Buoy list or details
                    if let selectedBuoy = selectedBuoy {
                        BuoyDetailView(
                            buoy: BuoyLocation(
                                region_buoy: selectedBuoy.organization,
                                latitude: Double(selectedBuoy.latitude) ?? 0.0,
                                longitude: Double(selectedBuoy.longitude) ?? 0.0,
                                name: selectedBuoy.name
                            ),
                            onBack: { self.selectedBuoy = nil },
                            showBackButton: true
                        )
                    } else {
                        buoyListView
                    }
                }
                .padding()
                .task {
                    await viewModel.loadBuoys()
                }
                .navigationTitle("Buoys")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ThemeToggleButton()
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 0)
                }
            }
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
                if viewModel.isRefreshing {
                    // Show skeleton loaders
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonListCard()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if viewModel.filteredBuoys.isEmpty {
                    // Empty state with glass design
                    VStack(spacing: 12) {
                        Image(systemName: "water.waves.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No buoys available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Pull to refresh")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.quaternary, lineWidth: 0.5)
                            )
                    )
                } else {
                    ForEach(viewModel.filteredBuoys) { buoy in
                        BuoyCard(buoy: buoy)
                            .onTapGesture {
                                selectedBuoy = buoy
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isRefreshing)
            .animation(.easeInOut(duration: 0.3), value: viewModel.filteredBuoys.count)
        }
        .refreshable {
            await viewModel.refreshBuoys()
        }
    }
    
    /// Calculates the appropriate maximum Y value for the chart based on historical data
    private func calculateChartMaxY(for buoy: Buoy) -> Double {
        // If no historical data, use the buoy's current max wave height
        guard !buoy.historicalData.isEmpty else {
            return max(buoy.maxWaveHeight + 1, 3.0) // Minimum scale of 3 meters
        }
        
        // Find the actual maximum from historical data
        let historicalMax = buoy.historicalData.map { $0.waveHeight }.max() ?? 0.0
        
        // Use the larger of current max or historical max, with some padding
        let dataMax = max(buoy.maxWaveHeight, historicalMax)
        
        // Add 20% padding to the top, with a minimum scale of 3 meters
        let paddedMax = dataMax * 1.2
        
        return max(paddedMax, 3.0)
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        )
    }
}


