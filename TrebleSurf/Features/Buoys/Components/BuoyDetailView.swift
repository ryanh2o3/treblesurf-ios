import SwiftUI
import Charts

struct BuoyDetailView: View {
    let buoy: BuoyLocation
    let onBack: () -> Void
    let showBackButton: Bool
    
    @StateObject private var viewModel = BuoysViewModel()
    @State private var similarReports: [SurfReport] = []
    @State private var isLoadingSimilarReports = false
    @State private var selectedReport: SurfReport?
    
    init(buoy: BuoyLocation, onBack: @escaping () -> Void, showBackButton: Bool = true) {
        self.buoy = buoy
        self.onBack = onBack
        self.showBackButton = showBackButton
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Back button
                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text(showBackButton ? "Back to Buoys" : "Back to Map")
                    }
                    .foregroundColor(.blue)
                }
                
                // Buoy info
                VStack(alignment: .leading, spacing: 12) {
                    Text(buoy.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Station • \(buoy.region_buoy)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let currentBuoy = viewModel.buoys.first(where: { $0.name == buoy.name }) {
                        Text("Last updated: \(currentBuoy.lastUpdated)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Current readings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Readings")
                        .font(.headline)
                    
                    if let currentBuoy = viewModel.buoys.first(where: { $0.name == buoy.name }) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            if !currentBuoy.waveHeight.isEmpty {
                                ReadingCard(title: "Wave Height", value: currentBuoy.waveHeight, unit: "m", icon: "water.waves")
                            }
                            if !currentBuoy.maxPeriod.isEmpty {
                                ReadingCard(title: "Period", value: currentBuoy.maxPeriod, unit: "sec", icon: "timer")
                            }
                            if !currentBuoy.windSpeed.isEmpty {
                                ReadingCard(title: "Wind Speed", value: currentBuoy.windSpeed, unit: "km/h", icon: "wind")
                            }
                            if !currentBuoy.waveDirection.isEmpty {
                                ReadingCard(title: "Direction", value: currentBuoy.waveDirection, unit: "°", icon: "arrow.up.right")
                            }
                            if !currentBuoy.waterTemp.isEmpty {
                                ReadingCard(title: "Water Temp", value: currentBuoy.waterTemp, unit: "°C", icon: "thermometer")
                            }
                            if !currentBuoy.airTemp.isEmpty {
                                ReadingCard(title: "Air Temp", value: currentBuoy.airTemp, unit: "°C", icon: "thermometer.sun")
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        // Skeleton loading for current readings
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(0..<6, id: \.self) { _ in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        SkeletonCircle()
                                            .frame(width: 20, height: 20)
                                        SkeletonLine(width: 80)
                                            .frame(height: 12)
                                    }
                                    SkeletonLine(width: 60)
                                        .frame(height: 20)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.quaternary, lineWidth: 0.5)
                                        )
                                )
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.buoys.isEmpty)
                
                // Wave height chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Wave Height (24h)")
                        .font(.headline)
                    
                    if #available(iOS 16.0, *) {
                        if let currentBuoy = viewModel.buoys.first(where: { $0.name == buoy.name }) {
                            if !currentBuoy.historicalData.isEmpty {
                                Chart(currentBuoy.historicalData) { dataPoint in
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
                                .chartYScale(domain: 0...calculateChartMaxY(for: currentBuoy))
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    Text("No historical data available")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            // Skeleton loading for chart
                            VStack(spacing: 8) {
                                SkeletonShape(cornerRadius: 12)
                                    .frame(height: 160)
                                HStack(spacing: 8) {
                                    ForEach(0..<5, id: \.self) { _ in
                                        SkeletonLine(width: 50)
                                            .frame(height: 8)
                                    }
                                }
                            }
                            .frame(height: 200)
                            .transition(.opacity)
                        }
                    } else {
                        // Fallback for iOS < 16
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(.orange)
                            Text("Chart requires iOS 16 or later")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.buoys.isEmpty)
                
                // Additional information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Buoy Information")
                        .font(.headline)
                    
                    Text("Location: \(buoy.latitude), \(buoy.longitude)")
                    if let currentBuoy = viewModel.buoys.first(where: { $0.name == buoy.name }) {
                        Text("Distance to shore: \(currentBuoy.distanceToShore) nautical miles")
                        Text("Depth: \(currentBuoy.depth)")
                    }
                }
                
                // Similar surf reports section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Surf Reports on Similar Conditions")
                        .font(.headline)
                    
                    if isLoadingSimilarReports {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading similar reports...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    } else if similarReports.isEmpty {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.secondary)
                            Text("No similar surf reports found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 15) {
                                ForEach(similarReports) { report in
                                    SurfReportCard(report: report)
                                        .onTapGesture {
                                            selectedReport = report
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .task {
            await viewModel.loadBuoys()
        }
        .onAppear {
            Task {
                // First load the buoys to get the Buoy objects
                await viewModel.loadBuoys()
                
                // Then find the corresponding Buoy and load its historical data
                if let currentBuoy = viewModel.buoys.first(where: { $0.name == buoy.name }) {
                    await viewModel.loadHistoricalDataForBuoy(id: currentBuoy.id) { updatedBuoy in
                        print("Historical data loaded for buoy: \(buoy.name)")
                    }
                    
                    // Load similar surf reports
                    loadSimilarSurfReports(for: currentBuoy)
                }
            }
        }
        .sheet(item: $selectedReport) { report in
            SurfReportDetailView(report: report, backButtonText: "Back to Buoy")
        }
        .padding(.horizontal, showBackButton ? 0 : 16)
        .padding(.bottom, showBackButton ? 0 : 20)
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
    
    /// Loads surf reports with similar buoy conditions
    private func loadSimilarSurfReports(for buoy: Buoy) {
        isLoadingSimilarReports = true
        
        // Parse buoy data
        guard let waveHeight = Double(buoy.waveHeight),
              let waveDirection = Double(buoy.waveDirection),
              let period = Double(buoy.maxPeriod) else {
            print("❌ Failed to parse buoy data for similar reports")
            isLoadingSimilarReports = false
            return
        }
        
        print("🌊 Fetching similar surf reports for buoy: \(buoy.name)")
        print("   - Wave Height: \(waveHeight)m")
        print("   - Wave Direction: \(waveDirection)°")
        print("   - Period: \(period)s")
        
        APIClient.shared.fetchSurfReportsWithSimilarBuoyData(
            waveHeight: waveHeight,
            waveDirection: waveDirection,
            period: period,
            buoyName: buoy.name,
            maxResults: 10
        ) { result in
            DispatchQueue.main.async {
                isLoadingSimilarReports = false
                
                switch result {
                case .success(let responses):
                    print("✅ Found \(responses.count) similar surf reports")
                    
                    // Convert responses to SurfReport objects
                    similarReports = responses.map { SurfReport(from: $0) }
                    
                    // Fetch images for the reports
                    for report in similarReports {
                        if let imageKey = report.imageKey, !imageKey.isEmpty {
                            fetchReportImage(for: report, imageKey: imageKey)
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Failed to fetch similar surf reports: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Fetches the image for a surf report
    private func fetchReportImage(for report: SurfReport, imageKey: String) {
        APIClient.shared.getReportImage(key: imageKey) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let imageResponse):
                    if let imageData = imageResponse.imageData {
                        report.imageData = imageData
                    }
                case .failure(let error):
                    print("❌ Failed to fetch image for report: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct BuoyDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleBuoy = BuoyLocation(
            region_buoy: "NorthAtlantic",
            latitude: 55.186844,
            longitude: -7.59785,
            name: "M4"
        )
        
        BuoyDetailView(buoy: sampleBuoy, onBack: {})
            .background(Color.gray.opacity(0.1))
    }
}
