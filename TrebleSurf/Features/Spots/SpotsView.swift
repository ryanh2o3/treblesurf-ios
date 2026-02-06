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
    @StateObject private var viewModel: SpotsViewModel
    @State private var selectedSpot: SpotData?
    @State private var selectedViewMode: String = "Live"
    @State private var selectedForecastEntry: ForecastEntry? = nil
    private let dependencies: AppDependencies
    
    init(dependencies: AppDependencies) {
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
        NavigationStack {
            MainLayout {
                VStack(spacing: 16) {
                    // Spots list or details
                    if let selectedSpot = selectedSpot {
                        SpotDetailView(
                            spot: selectedSpot,
                            onBack: { self.selectedSpot = nil },
                            showBackButton: true,
                            dependencies: dependencies
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
                .navigationTitle("Spots")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ThemeToggleButton()
                    }
                }
            }
        }
    }
    
    private var spotsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading {
                    // Show skeleton loaders
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonListCard()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if viewModel.spots.isEmpty {
                    // Empty state with glass design
                    VStack(spacing: 12) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No spots available")
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
                    ForEach(viewModel.spots) { spot in
                        SpotCard(spot: spot)
                            .onTapGesture {
                                selectedSpot = spot
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
            .animation(.easeInOut(duration: 0.3), value: viewModel.spots.count)
        }
        .refreshable {
            await viewModel.refreshSpots()
            await viewModel.refreshSurfReports()
        }
        .safeAreaInset(edge: .bottom) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 0)
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

// Overlay components for the shared spot image
struct LiveSpotOverlay: View {
    @EnvironmentObject var dataStore: DataStore
    let spotId: String
    let aiPrediction: SwellPredictionEntry?
    
    var body: some View {
        ZStack {
            // Direction arrows - centered
            HStack(spacing: 8) {
                // Swell arrow - purple if AI prediction available, blue otherwise
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(aiPrediction != nil ? .purple : .blue)
                        .rotationEffect(Angle(degrees: aiPrediction?.predictedDirection ?? dataStore.currentConditions.swellDirection))
                        .animation(.easeInOut(duration: 0.4), value: aiPrediction?.id)
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
                        .fill(aiPrediction != nil ? Color.purple : Color.blue)
                        .frame(width: 12, height: 12)
                    Text(aiPrediction != nil ? "AI Swell" : "Swell")
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
            Task { _ = await dataStore.fetchConditions(for: spotId) }
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
    let dependencies = AppDependencies()
    SpotsView(dependencies: dependencies)
        .environmentObject(dependencies.dataStore)
}
