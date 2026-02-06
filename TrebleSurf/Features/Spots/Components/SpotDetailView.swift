import SwiftUI

struct SpotDetailView: View {
    let spot: SpotData
    let onBack: () -> Void
    let showBackButton: Bool
    private let dependencies: AppDependencies
    
    @StateObject private var viewModel: SpotsViewModel
    @EnvironmentObject var swellPredictionService: SwellPredictionService
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedViewMode: String = "Live"
    @State private var selectedForecastEntry: ForecastEntry? = nil
    @State private var selectedSwellPrediction: SwellPredictionEntry? = nil
    @State private var liveAIPrediction: SwellPredictionEntry? = nil
    @State private var isLoadingAI = false
    @State private var aiErrorMessage: String? = nil
    
    init(
        spot: SpotData,
        onBack: @escaping () -> Void,
        showBackButton: Bool = true,
        dependencies: AppDependencies
    ) {
        self.spot = spot
        self.onBack = onBack
        self.showBackButton = showBackButton
        self.dependencies = dependencies
        _viewModel = StateObject(
            wrappedValue: SpotsViewModel(
                dataStore: dependencies.dataStore,
                apiClient: dependencies.apiClient,
                surfReportService: dependencies.surfReportService,
                errorHandler: dependencies.errorHandler,
                logger: dependencies.errorLogger
            )
        )
    }
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Back button and spot info
                    HStack() {
                        Button(action: onBack) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                Text(showBackButton ? "Back to Spots" : "Back to Map")
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Text("\(spot.type) • \(spot.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Refresh indicator
                        if viewModel.isRefreshing {
                            ZStack {
                                Circle()
                                    .stroke(lineWidth: 2)
                                    .foregroundColor(.gray.opacity(0.2))
                                    .frame(width: 20, height: 20)
                                
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .foregroundColor(.blue)
                                    .frame(width: 20, height: 20)
                                    .rotationEffect(Angle(degrees: viewModel.isRefreshing ? 360 : 0))
                                    .animation(
                                        Animation.linear(duration: 1)
                                            .repeatForever(autoreverses: false),
                                        value: viewModel.isRefreshing
                                    )
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    // Spot image - moved here to be shared between live and forecast views
                    if let imageString = spot.imageString, !imageString.isEmpty,
                       let uiImage = imageString.toUIImage() {
                        GeometryReader { geometry in
                            ZStack(alignment: .bottom) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: 200)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            // Overlay with key data and direction arrow - shared between both views
                            VStack(spacing: 12) {
                                // Key data display - will be populated by child views
                                if selectedViewMode == "Live" {
                                    LiveSpotOverlay(spotId: spot.id, aiPrediction: liveAIPrediction)
                                        .environmentObject(dataStore)
                                } else {
                                    EnhancedSpotOverlay(
                                        spotId: spot.id, 
                                        selectedForecastEntry: selectedForecastEntry,
                                        selectedSwellPrediction: selectedSwellPrediction
                                    )
                                }
                                }
                                .padding(.bottom, 8)
                                .animation(.easeInOut(duration: 0.3), value: selectedViewMode)
                            }
                        }
                        .frame(height: 200)
                        .padding(.bottom, 8)
                    }
                    
                    // View mode toggle - centered with more spacing
                    HStack {
                        Spacer()
                        HStack(spacing: 0) {
                            ForEach(["Live", "Forecast"], id: \.self) { mode in
                                let isSelected = selectedViewMode == mode
                                
                                Button(action: { 
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedViewMode = mode
                                        selectedForecastEntry = nil // Clear forecast entry when switching
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: mode == "Live" ? "wave.3.right" : "calendar")
                                            .font(.caption)
                                        Text(mode)
                                            .font(.footnote)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isSelected ? Color.blue : Color.clear)
                                    )
                                    .scaleEffect(isSelected ? 1.02 : 1.0)
                                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                        Spacer()
                    }
                    
                    // Content based on selected view mode
                    if selectedViewMode == "Live" {
                        LiveSpotView(
                            spotId: spot.id,
                            refreshTrigger: viewModel.isRefreshing,
                            spotImage: nil,
                            aiPrediction: liveAIPrediction,
                            dependencies: dependencies
                        )
                            .id(spot.id)
                            .clipped()
                    } else {
                        EnhancedForecastView(
                            spot: spot,
                            dataStore: dataStore,
                            spotImage: nil,
                            onForecastSelectionChanged: { forecastEntry in
                                selectedForecastEntry = forecastEntry
                            },
                            onSwellPredictionSelectionChanged: { swellPrediction in
                                selectedSwellPrediction = swellPrediction
                            }
                        )
                        .id(spot.id)
                        .clipped()
                    }
                }
                .padding(.vertical)
                .padding(.horizontal, 8)
            }
            Spacer()
        }
        .refreshable {
            // Refresh the specific spot data
            await viewModel.refreshSpotData(for: spot.id)
            
            // Refresh surf reports for this specific spot
            await viewModel.refreshSpotSurfReports(for: spot)
            
            // Refresh based on current view mode
            if selectedViewMode == "Live" {
                _ = await dataStore.fetchConditions(for: spot.id)
            }
        }
        .onAppear {
            viewModel.setDataStore(dataStore)
            fetchLiveAIPrediction()
        }
        .padding(.horizontal, showBackButton ? 0 : 16)
        .padding(.bottom, showBackButton ? 0 : 20)
    }
    
    private func fetchLiveAIPrediction() {
        // Convert spotId back to country/region/spot format
        let components = spot.id.split(separator: "#")
        guard components.count >= 3 else {
            aiErrorMessage = "Invalid spot ID format"
            return
        }

        let country = String(components[0])
        let region = String(components[1])
        let spotName = String(components[2])

        isLoadingAI = true
        aiErrorMessage = nil

        Task {
            do {
                let response = try await dependencies.apiClient.fetchClosestAIPrediction(country: country, region: region, spot: spotName)
                self.isLoadingAI = false
                self.liveAIPrediction = SwellPredictionEntry(from: response)
            } catch {
                self.isLoadingAI = false
                self.aiErrorMessage = "Failed to load AI prediction: \(error.localizedDescription)"
            }
        }
    }
}

struct SpotDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSpot = SpotData(
            beachDirection: 270,
            idealSwellDirection: "W",
            latitude: 55.186844,
            longitude: -7.59785,
            type: "Beach",
            countryRegionSpot: "Ireland/Donegal/Bundoran",
            image: "",
            imageString: nil
        )
        
        let dependencies = AppDependencies()
        return SpotDetailView(spot: sampleSpot, onBack: {}, dependencies: dependencies)
            .background(Color.gray.opacity(0.1))
            .environmentObject(dependencies.dataStore)
            .environmentObject(dependencies.swellPredictionService)
    }
}
