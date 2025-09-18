import SwiftUI

struct SpotDetailView: View {
    let spot: SpotData
    let onBack: () -> Void
    let showBackButton: Bool
    
    @StateObject private var viewModel = SpotsViewModel()
    @State private var selectedViewMode: String = "Live"
    @State private var selectedForecastEntry: ForecastEntry? = nil
    
    init(spot: SpotData, onBack: @escaping () -> Void, showBackButton: Bool = true) {
        self.spot = spot
        self.onBack = onBack
        self.showBackButton = showBackButton
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
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .padding(.top, 8)
                    
                    // Spot image - moved here to be shared between live and forecast views
                    if let imageString = spot.imageString, !imageString.isEmpty,
                       let uiImage = imageString.toUIImage() {
                        ZStack(alignment: .bottom) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            // Overlay with key data and direction arrow - shared between both views
                            VStack(spacing: 12) {
                                // Key data display - will be populated by child views
                                if selectedViewMode == "Live" {
                                    LiveSpotOverlay(spotId: spot.id)
                                } else {
                                    ForecastSpotOverlay(spotId: spot.id, selectedForecastEntry: selectedForecastEntry)
                                }
                            }
                            .padding(.bottom, 8)
                            .animation(.easeInOut(duration: 0.3), value: selectedViewMode)
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 8)
                    }
                    
                    // View mode toggle - moved here to save space
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
                                .padding(.vertical, 6)
                                .padding(.horizontal, 6)
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
                    .padding(.horizontal, 6)
                    
                    // Content based on selected view mode
                    if selectedViewMode == "Live" {
                        LiveSpotView(spotId: spot.id, refreshTrigger: viewModel.isRefreshing, spotImage: nil)
                            .id(spot.id)
                            .clipped()
                    } else {
                        SpotForecastView(
                            spotId: spot.id, 
                            spotImage: nil,
                            onForecastSelectionChanged: { forecastEntry in
                                selectedForecastEntry = forecastEntry
                            }
                        )
                        .id(spot.id)
                        .clipped()
                    }
                }
                .padding()
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
                DataStore.shared.fetchConditions(for: spot.id) { _ in }
            }
        }
        .onAppear {
            viewModel.setDataStore(DataStore.shared)
        }
        .padding(.horizontal, showBackButton ? 0 : 16)
        .padding(.bottom, showBackButton ? 0 : 20)
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
        
        SpotDetailView(spot: sampleSpot, onBack: {})
            .background(Color.gray.opacity(0.1))
    }
}
