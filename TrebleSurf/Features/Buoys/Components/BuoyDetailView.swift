import SwiftUI
import Charts

struct BuoyDetailView: View {
    let buoy: BuoyLocation
    let onBack: () -> Void
    let showBackButton: Bool
    
    @StateObject private var viewModel: BuoysViewModel
    private let apiClient: APIClientProtocol
    @State private var similarReports: [SurfReport] = []
    @State private var isLoadingSimilarReports = false
    @State private var selectedReport: SurfReport?
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    @State private var isLoadingCustomData = false
    @State private var dateRangeMode: DateRangeMode = .last24Hours
    @State private var selectedTimePoint: Date?
    @State private var selectedDataPoint: BuoyResponse?
    @State private var isLoadingExtendedData = false
    @State private var selectionDebounceTask: Task<Void, Never>?
    
    enum DateRangeMode {
        case last24Hours
        case customDate
    }
    
    init(
        buoy: BuoyLocation,
        onBack: @escaping () -> Void,
        showBackButton: Bool = true,
        dependencies: AppDependencies
    ) {
        self.buoy = buoy
        self.onBack = onBack
        self.showBackButton = showBackButton
        self.apiClient = dependencies.apiClient
        _viewModel = StateObject(
            wrappedValue: BuoysViewModel(
                weatherBuoyService: dependencies.weatherBuoyService,
                buoyCacheService: dependencies.buoyCacheService,
                apiClient: dependencies.apiClient,
                errorHandler: dependencies.errorHandler,
                logger: dependencies.errorLogger
            )
        )
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
                    HStack {
                        Text(readingsTitle)
                            .font(.headline)
                        
                        if selectedTimePoint != nil {
                            Spacer()
                            Button(action: {
                                selectedTimePoint = nil
                                selectedDataPoint = nil
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12))
                                    Text("Current")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                        }
                    }
                    
                    if let currentBuoy = viewModel.buoys.first(where: { $0.name == buoy.name }) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            if let waveHeight = displayedWaveHeight(for: currentBuoy) {
                                ReadingCard(title: "Wave Height", value: waveHeight, unit: "m", icon: "water.waves")
                            }
                            if let period = displayedPeriod(for: currentBuoy) {
                                ReadingCard(title: "Period", value: period, unit: "sec", icon: "timer")
                            }
                            if let windSpeed = displayedWindSpeed(for: currentBuoy) {
                                ReadingCard(title: "Wind Speed", value: windSpeed, unit: "km/h", icon: "wind")
                            }
                            if let waveDirection = displayedWaveDirection(for: currentBuoy) {
                                ReadingCard(title: "Direction", value: waveDirection, unit: "°", icon: "arrow.up.right")
                            }
                            if let waterTemp = displayedWaterTemp(for: currentBuoy) {
                                ReadingCard(title: "Water Temp", value: waterTemp, unit: "°C", icon: "thermometer")
                            }
                            if let airTemp = displayedAirTemp(for: currentBuoy) {
                                ReadingCard(title: "Air Temp", value: airTemp, unit: "°C", icon: "thermometer.sun")
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
                
                // Date range selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Historical Data")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        // Last 24 Hours button
                        Button(action: {
                            dateRangeMode = .last24Hours
                            loadLast24HoursData()
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.system(size: 14))
                                Text("Last 24h")
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(dateRangeMode == .last24Hours ? Color.blue : Color(.systemGray6))
                            )
                            .foregroundColor(dateRangeMode == .last24Hours ? .white : .primary)
                        }
                        
                        // Custom date button
                        Button(action: {
                            showDatePicker.toggle()
                        }) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                Text(dateRangeMode == .customDate ? formatDateShort(selectedDate) : "Pick Date")
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(dateRangeMode == .customDate ? Color.blue : Color(.systemGray6))
                            )
                            .foregroundColor(dateRangeMode == .customDate ? .white : .primary)
                        }
                        
                        if isLoadingCustomData {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        Spacer()
                    }
                    
                    // Date picker sheet
                    if showDatePicker {
                        VStack(spacing: 12) {
                            DatePicker(
                                "Select Date",
                                selection: $selectedDate,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            )
                            
                            Button(action: {
                                dateRangeMode = .customDate
                                showDatePicker = false
                                loadCustomDateData()
                            }) {
                                Text("Load Data")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showDatePicker)
                
                // Wave height chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(chartTitle)
                            .font(.headline)
                        
                        if isLoadingExtendedData {
                            Spacer()
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
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
                                    
                                    // Add selection line if a time point is selected
                                    if let selectedTime = selectedTimePoint {
                                        RuleMark(x: .value("Selected Time", selectedTime))
                                            .foregroundStyle(Color.orange)
                                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                                            .annotation(position: .top, alignment: .center) {
                                                Text(formatTime(selectedTime))
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .fill(Color.orange)
                                                    )
                                            }
                                    }
                                }
                                .frame(height: 200)
                                .chartYScale(domain: 0...calculateChartMaxY(for: currentBuoy))
                                .chartXSelection(value: $selectedTimePoint)
                                .onChange(of: selectedTimePoint) { newValue in
                                    if let newTime = newValue {
                                        updateSelectedDataPoint(for: newTime, buoy: currentBuoy)
                                        
                                        // Cancel any existing debounce task
                                        selectionDebounceTask?.cancel()
                                        
                                        // Check if selected time is outside loaded range
                                        if isTimeOutsideLoadedRange(newTime, buoy: currentBuoy) {
                                            // Debounce the data loading - wait 0.5 seconds after user stops
                                            selectionDebounceTask = Task {
                                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                                
                                                if !Task.isCancelled {
                                                    await loadDataAroundTime(newTime, for: currentBuoy)
                                                }
                                            }
                                        }
                                    }
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    Text(emptyStateMessage)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
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
            SurfReportDetailView(
                report: report,
                backButtonText: "Back to Buoy",
                apiClient: apiClient
            )
        }
        .onDisappear {
            // Clean up any pending tasks
            selectionDebounceTask?.cancel()
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
        
        Task {
            do {
                let responses = try await apiClient.fetchSurfReportsWithSimilarBuoyData(
                    waveHeight: waveHeight,
                    waveDirection: waveDirection,
                    period: period,
                    buoyName: buoy.name,
                    maxResults: 10
                )
                
                isLoadingSimilarReports = false
                print("✅ Found \(responses.count) similar surf reports")
                
                // Convert responses to SurfReport objects
                similarReports = responses.map { SurfReport(from: $0) }
                
                // Fetch images for the reports
                for report in similarReports {
                    if let imageKey = report.imageKey, !imageKey.isEmpty {
                        fetchReportImage(for: report, imageKey: imageKey)
                    }
                }
            } catch {
                isLoadingSimilarReports = false
                print("❌ Failed to fetch similar surf reports: \(error.localizedDescription)")
            }
        }
    }
    
    /// Fetches the image for a surf report
    private func fetchReportImage(for report: SurfReport, imageKey: String) {
        Task {
            do {
                let imageResponse = try await apiClient.getReportImage(key: imageKey)
                if let imageData = imageResponse.imageData {
                    report.imageData = imageData
                }
            } catch {
                print("❌ Failed to fetch image for report: \(error.localizedDescription)")
            }
        }
    }
    
    /// Loads last 24 hours of buoy data
    private func loadLast24HoursData() {
        // Cancel any pending debounce task
        selectionDebounceTask?.cancel()
        
        // Reset selection when loading new data
        selectedTimePoint = nil
        selectedDataPoint = nil
        
        Task {
            if let currentBuoy = viewModel.buoys.first(where: { $0.name == buoy.name }) {
                await viewModel.loadHistoricalDataForBuoy(id: currentBuoy.id) { updatedBuoy in
                    print("Loaded last 24h data for buoy: \(buoy.name)")
                }
            }
        }
    }
    
    /// Loads buoy data for the selected custom date (24 hours from that date)
    private func loadCustomDateData() {
        // Cancel any pending debounce task
        selectionDebounceTask?.cancel()
        
        isLoadingCustomData = true
        
        // Reset selection when loading new data
        selectedTimePoint = nil
        selectedDataPoint = nil
        
        Task {
            if let currentBuoy = viewModel.buoys.first(where: { $0.name == buoy.name }) {
                // Get the start of the selected date
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: selectedDate)
                
                // Get 24 hours from that date
                let endDate = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
                
                await viewModel.loadHistoricalDataForBuoyDateRange(
                    id: currentBuoy.id,
                    startDate: startOfDay,
                    endDate: endDate
                ) { updatedBuoy in
                    print("Loaded custom date data for buoy: \(buoy.name)")
                }
            }
            
            isLoadingCustomData = false
        }
    }
    
    /// Formats a date to a short string (e.g., "Nov 9")
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    /// Computed property for chart title based on date range mode
    private var chartTitle: String {
        switch dateRangeMode {
        case .last24Hours:
            return "Wave Height (Last 24h)"
        case .customDate:
            return "Wave Height (\(formatDateShort(selectedDate)))"
        }
    }
    
    /// Computed property for empty state message based on date range mode
    private var emptyStateMessage: String {
        switch dateRangeMode {
        case .last24Hours:
            return "No historical data available for the last 24 hours"
        case .customDate:
            return "No data available for \(formatDateShort(selectedDate))\nTry selecting a different date"
        }
    }
    
    /// Computed property for readings title
    private var readingsTitle: String {
        if selectedTimePoint != nil {
            return "Selected Time Readings"
        } else {
            return "Current Readings"
        }
    }
    
    /// Formats a time to a short string (e.g., "10:30 AM")
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    /// Updates the selected data point based on the selected time
    private func updateSelectedDataPoint(for time: Date, buoy: Buoy) {
        // Find the closest historical data point to the selected time
        guard let closestDataPoint = findClosestDataPoint(to: time, in: buoy.historicalData) else {
            return
        }
        
        // Find the corresponding BuoyResponse from historicalResponses
        // Match by finding the response with the closest timestamp
        if let closestResponse = findClosestBuoyResponse(to: closestDataPoint.time, in: buoy.historicalResponses) {
            selectedDataPoint = closestResponse
            print("✅ Selected time: \(formatTime(time)), Wave Height: \(closestDataPoint.waveHeight)m")
        } else {
            selectedDataPoint = nil
            print("⚠️ No matching BuoyResponse found for selected time")
        }
    }
    
    /// Finds the closest BuoyResponse to a given time
    private func findClosestBuoyResponse(to targetTime: Date, in responses: [BuoyResponse]) -> BuoyResponse? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        return responses.min(by: { response1, response2 in
            guard let dateStr1 = response1.dataDateTime,
                  let dateStr2 = response2.dataDateTime,
                  let date1 = formatter.date(from: dateStr1),
                  let date2 = formatter.date(from: dateStr2) else {
                return false
            }
            
            return abs(date1.timeIntervalSince(targetTime)) < abs(date2.timeIntervalSince(targetTime))
        })
    }
    
    /// Finds the closest data point to a given time
    private func findClosestDataPoint(to targetTime: Date, in dataPoints: [WaveDataPoint]) -> WaveDataPoint? {
        return dataPoints.min(by: { abs($0.time.timeIntervalSince(targetTime)) < abs($1.time.timeIntervalSince(targetTime)) })
    }
    
    // MARK: - Display Value Helpers
    
    /// Returns the wave height to display (either selected or current)
    private func displayedWaveHeight(for buoy: Buoy) -> String? {
        if let selected = selectedDataPoint, let height = selected.WaveHeight {
            return String(format: "%.2f", height)
        }
        return buoy.waveHeight.isEmpty ? nil : buoy.waveHeight
    }
    
    /// Returns the period to display (either selected or current)
    private func displayedPeriod(for buoy: Buoy) -> String? {
        if let selected = selectedDataPoint, let period = selected.MaxPeriod {
            return String(format: "%.1f", period)
        }
        return buoy.maxPeriod.isEmpty ? nil : buoy.maxPeriod
    }
    
    /// Returns the wind speed to display (either selected or current)
    private func displayedWindSpeed(for buoy: Buoy) -> String? {
        if let selected = selectedDataPoint, let speed = selected.WindSpeed {
            return String(format: "%.1f", speed)
        }
        return buoy.windSpeed.isEmpty ? nil : buoy.windSpeed
    }
    
    /// Returns the wave direction to display (either selected or current)
    private func displayedWaveDirection(for buoy: Buoy) -> String? {
        if let selected = selectedDataPoint, let direction = selected.MeanWaveDirection {
            return String(direction)
        }
        return buoy.waveDirection.isEmpty ? nil : buoy.waveDirection
    }
    
    /// Returns the water temp to display (either selected or current)
    private func displayedWaterTemp(for buoy: Buoy) -> String? {
        if let selected = selectedDataPoint, let temp = selected.SeaTemperature {
            return String(format: "%.1f", temp)
        }
        return buoy.waterTemp.isEmpty ? nil : buoy.waterTemp
    }
    
    /// Returns the air temp to display (either selected or current)
    private func displayedAirTemp(for buoy: Buoy) -> String? {
        if let selected = selectedDataPoint, let temp = selected.AirTemperature {
            return String(format: "%.1f", temp)
        }
        return buoy.airTemp.isEmpty ? nil : buoy.airTemp
    }
    
    // MARK: - Extended Data Loading
    
    /// Checks if the selected time is outside the currently loaded data range
    private func isTimeOutsideLoadedRange(_ time: Date, buoy: Buoy) -> Bool {
        guard !buoy.historicalData.isEmpty else { return true }
        
        // Get the min and max times in the loaded data
        let times = buoy.historicalData.map { $0.time }
        guard let minTime = times.min(), let maxTime = times.max() else { return true }
        
        // Add a small buffer (5 minutes) to avoid loading when just near the edge
        let bufferSeconds: TimeInterval = 5 * 60
        let bufferedMinTime = minTime.addingTimeInterval(-bufferSeconds)
        let bufferedMaxTime = maxTime.addingTimeInterval(bufferSeconds)
        
        // Check if time is outside the range
        return time < bufferedMinTime || time > bufferedMaxTime
    }
    
    /// Loads 24 hours of data centered around the selected time
    @MainActor
    private func loadDataAroundTime(_ time: Date, for buoy: Buoy) async {
        // Prevent multiple simultaneous loads
        guard !isLoadingExtendedData else { return }
        
        isLoadingExtendedData = true
        
        print("📊 Loading data around time: \(formatTime(time))")
        
        // Calculate 24-hour range centered on selected time (±12 hours)
        let startDate = time.addingTimeInterval(-12 * 60 * 60) // 12 hours before
        let endDate = time.addingTimeInterval(12 * 60 * 60)    // 12 hours after
        
        await viewModel.loadHistoricalDataForBuoyDateRange(
            id: buoy.id,
            startDate: startDate,
            endDate: endDate
        ) { updatedBuoy in
            print("✅ Extended data loaded for buoy: \(buoy.name)")
            
            // Re-select the time point to update the data point with new data
            if let selectedTime = self.selectedTimePoint {
                if let currentBuoy = self.viewModel.buoys.first(where: { $0.name == buoy.name }) {
                    self.updateSelectedDataPoint(for: selectedTime, buoy: currentBuoy)
                }
            }
        }
        
        isLoadingExtendedData = false
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
        
        BuoyDetailView(buoy: sampleBuoy, onBack: {}, dependencies: AppDependencies())
            .background(Color.gray.opacity(0.1))
    }
}
