// SpotsView.swift
import SwiftUI
import UIKit

// Helper extension for safe base64 image conversion
extension String {
    func toUIImage() -> UIImage? {
        guard !self.isEmpty else {
            print("Debug: Empty image string")
            return nil
        }
        
        guard let data = Data(base64Encoded: self) else {
            print("Debug: Failed to decode base64 string for image")
            return nil
        }
        
        guard let image = UIImage(data: data) else {
            print("Debug: Failed to create UIImage from data")
            return nil
        }
        
        return image
    }
}

struct SpotsView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var viewModel: SpotsViewModel = SpotsViewModel()
    @State private var selectedSpot: SpotData?
    @State private var selectedViewMode: String = "Live"
    @State private var selectedForecastEntry: ForecastEntry? = nil
    
    var body: some View {
        NavigationView {
            MainLayout {
                VStack(spacing: 16) {
                    // Header with title and theme toggle
                    HStack {
                        Text("Spots")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        ThemeToggleButton()
                    }
                    .padding(.horizontal)
                    
                    // Spots list or details
                    if let selectedSpot = selectedSpot {
                        spotDetailView(selectedSpot)
                    } else {
                        spotsListView
                    }
                }
                .padding()
                .task {
                    viewModel.setDataStore(dataStore)
                    await viewModel.loadSpots()
                }
            }
            .navigationBarHidden(true)

        }
    }
    

    
    private var spotsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else if viewModel.spots.isEmpty {
                    Text("No spots available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    ForEach(viewModel.spots) { spot in
                        SpotCard(spot: spot)
                            .onTapGesture {
                                selectedSpot = spot
                            }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refreshSpots()
            await viewModel.refreshSurfReports()
        }
    }
    
    private func spotDetailView(_ spot: SpotData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Back button and spot info
                HStack() {
                    Button {
                        selectedSpot = nil
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Back to Spots")
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
                
                // Spot image - moved here to be shared between live and forecast views
                if let imageString = spot.imageString, !imageString.isEmpty,
                   let uiImage = imageString.toUIImage() {
                    ZStack(alignment: .bottom) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
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
                    Button(action: { 
                        selectedViewMode = "Live"
                        selectedForecastEntry = nil // Clear forecast entry when switching to live
                    }) {
                        Text("Live")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedViewMode == "Live" ? Color.blue : Color(.systemGray5))
                            )
                            .foregroundColor(selectedViewMode == "Live" ? .white : .primary)
                    }
                    
                    Button(action: { 
                        selectedViewMode = "Forecast"
                        selectedForecastEntry = nil // Clear forecast entry when switching to forecast
                    }) {
                        Text("Forecast")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedViewMode == "Forecast" ? Color.blue : Color(.systemGray5))
                            )
                            .foregroundColor(selectedViewMode == "Forecast" ? .white : .primary)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
                .padding(.vertical, 8)
                
                // Content based on selected view mode
                if selectedViewMode == "Live" {
                    LiveSpotView(spotId: spot.id, refreshTrigger: viewModel.isRefreshing, spotImage: nil)
                        .id(spot.id)
                        .frame(maxWidth: .infinity)
                } else {
                    SpotForecastView(
                        spotId: spot.id, 
                        spotImage: nil,
                        onForecastSelectionChanged: { forecastEntry in
                            selectedForecastEntry = forecastEntry
                        }
                    )
                    .id(spot.id)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .refreshable {
            // Refresh the specific spot data
            await viewModel.refreshSpotData(for: spot.id)
            
            // Refresh surf reports for this specific spot
            await viewModel.refreshSpotSurfReports(for: spot)
            
            // Refresh based on current view mode
            if selectedViewMode == "Live" {
                dataStore.fetchConditions(for: spot.id) { _ in }
            }
        }
    }
}

struct SpotCard: View {
    let spot: SpotData
    
    var body: some View {
        HStack(spacing: 12) {
            // Spot icon with type indicator or spot image
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                // Show spot image if available, otherwise show wave icon
                if let imageString = spot.imageString, !imageString.isEmpty,
                   let uiImage = imageString.toUIImage() {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .accessibilityLabel("Spot image for \(spot.name)")
                } else {
                    Image(systemName: "water.waves")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .accessibilityLabel("Wave icon for \(spot.name)")
                }
                
                Text(spot.type.prefix(1))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .offset(x: 16, y: -16)
            }
            
            // Spot information
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name)
                    .font(.headline)
                
                Text(spot.type)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Label {
                        Text("\(spot.beachDirection)°")
                    } icon: {
                        Image(systemName: "location.north")
                            .foregroundColor(.blue)
                    }
                    .font(.caption)
                    
                    Label {
                        Text(spot.idealSwellDirection)
                    } icon: {
                        Image(systemName: "water.waves")
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

// Overlay components for the shared spot image
struct LiveSpotOverlay: View {
    @EnvironmentObject var dataStore: DataStore
    let spotId: String
    
    var body: some View {
        VStack(spacing: 8) {
            // Key data display for live view
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Swell")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("\(dataStore.currentConditions.swellHeight, specifier: "%.1f")m")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 4) {
                    Text("Wind")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("\(Int(dataStore.currentConditions.windSpeed * 3.6)) km/h")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 4) {
                    Text("Temp")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("\(Int(dataStore.currentConditions.temperature))°C")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
            
            // Direction arrow for live view
            Image(systemName: "arrow.down")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
                .rotationEffect(Angle(degrees: dataStore.currentConditions.swellDirection))
                .scaleEffect(1.0)
        }
        .onAppear {
            // Fetch current conditions when overlay appears
            dataStore.fetchConditions(for: spotId) { _ in }
        }
    }
}

struct ForecastSpotOverlay: View {
    @EnvironmentObject var dataStore: DataStore
    let spotId: String
    let selectedForecastEntry: ForecastEntry?
    
    var body: some View {
        VStack(spacing: 8) {
            // Key data display for forecast view
            if let entry = selectedForecastEntry {
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
            
            // Direction arrow for forecast view
            Image(systemName: "arrow.down")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
                .rotationEffect(Angle(degrees: selectedForecastEntry?.swellDirection ?? dataStore.currentConditions.swellDirection))
                .animation(.easeInOut(duration: 0.4), value: selectedForecastEntry?.id)
                .scaleEffect(1.0)
        }
    }
}

#Preview {
    SpotsView()
        .environmentObject(DataStore())
}
