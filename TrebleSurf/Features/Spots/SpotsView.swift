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
                        SpotDetailView(
                            spot: selectedSpot,
                            onBack: { self.selectedSpot = nil },
                            showBackButton: true
                        )
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
        ZStack {
            // Direction arrows - centered
            HStack(spacing: 8) {
                // Swell arrow (blue)
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.blue)
                        .rotationEffect(Angle(degrees: dataStore.currentConditions.swellDirection))
                        .scaleEffect(1.0)
                }
                
                // Wind arrow (white)
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(Angle(degrees: dataStore.currentConditions.windDirection))
                        .scaleEffect(1.0)
                }
            }
            
            // Legends in top right
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                    Text("Swell")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                    Text("Wind")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(maxHeight: .infinity, alignment: .top)
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
        ZStack {
            // Direction arrows - centered
            HStack(spacing: 8) {
                // Swell arrow (blue)
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.blue)
                        .rotationEffect(Angle(degrees: selectedForecastEntry?.swellDirection ?? dataStore.currentConditions.swellDirection))
                        .animation(.easeInOut(duration: 0.4), value: selectedForecastEntry?.id)
                        .scaleEffect(1.0)
                }
                
                // Wind arrow (white)
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(Angle(degrees: selectedForecastEntry?.windDirection ?? dataStore.currentConditions.windDirection))
                        .animation(.easeInOut(duration: 0.4), value: selectedForecastEntry?.id)
                        .scaleEffect(1.0)
                }
            }
            
            // Legends in top right
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                    Text("Swell")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                    Text("Wind")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview {
    SpotsView()
        .environmentObject(DataStore())
}
