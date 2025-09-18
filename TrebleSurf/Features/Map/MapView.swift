import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.186844, longitude: -7.59785),
        span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
    )
    
    var body: some View {
        NavigationView {
            MainLayout {
                ZStack {
                    // Map with markers - simplified structure
                    MapContentView(
                        viewModel: viewModel,
                        region: $region
                    )
                    .ignoresSafeArea(.all, edges: .top)
                    .mapStyle(.standard(elevation: .realistic))
                    .mapControlVisibility(.hidden)
                    .allowsHitTesting(true)
                    .onTapGesture(count: 2) {
                        // Double-tap to return to overview
                        withAnimation(.easeInOut(duration: 0.5)) {
                            region = viewModel.getUltraStableMapRegion()
                        }
                        viewModel.clearSelection()
                    }
                    .onAppear {
                        // Set initial region based on loaded data
                        region = viewModel.getUltraStableMapRegion()
                    }
                    .onChange(of: viewModel.surfSpots) { oldValue, newValue in
                        // Update region when spots are loaded
                        region = viewModel.getUltraStableMapRegion()
                    }
                    .onChange(of: viewModel.buoys) { oldValue, newValue in
                        // Update region when buoys are loaded
                        region = viewModel.getUltraStableMapRegion()
                    }
                    
                    // Loading indicator
                    if viewModel.isLoading {
                        VStack {
                            ProgressView("Loading map data...")
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 100)
                    }
                    
                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        VStack {
                            Text("Error")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Retry") {
                                viewModel.loadMapData()
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 100)
                    }
                    
                    // Refresh button
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                viewModel.loadMapData()
                            }) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .background(
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 24, height: 24)
                                    )
                            }
                            .padding(.trailing, 20)
                        }
                        Spacer()
                    }
                    .padding(.top, 100)
                    
                    // Info panel at bottom
                    VStack {
                        Spacer()
                        // Show info panel or detail view based on selection
                        if let selectedSpot = viewModel.selectedSpot {
                            if viewModel.showingSpotDetails {
                                SpotDetailView(
                                    spot: selectedSpot,
                                    onBack: { viewModel.clearSelection() },
                                    showBackButton: false
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .shadow(radius: 8)
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            } else {
                                MapInfoPanel(
                                    selectedSpot: selectedSpot,
                                    selectedBuoy: nil,
                                    spotConditions: viewModel.selectedSpotConditions,
                                    isLoadingConditions: viewModel.isLoadingConditions,
                                    conditionsTimestamp: nil,
                                    onClose: { viewModel.clearSelection() },
                                    onZoomOut: { viewModel.zoomOutToOverview() },
                                    onViewDetails: { viewModel.showSpotDetails() }
                                )
                            }
                        } else if let selectedBuoy = viewModel.selectedBuoy {
                            if viewModel.showingBuoyDetails {
                                BuoyDetailView(
                                    buoy: selectedBuoy,
                                    onBack: { viewModel.clearSelection() },
                                    showBackButton: false
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .shadow(radius: 8)
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            } else {
                                MapInfoPanel(
                                    selectedSpot: nil,
                                    selectedBuoy: selectedBuoy,
                                    spotConditions: nil,
                                    isLoadingConditions: false,
                                    conditionsTimestamp: nil,
                                    onClose: { viewModel.clearSelection() },
                                    onZoomOut: { viewModel.zoomOutToOverview() },
                                    onViewDetails: { viewModel.showBuoyDetails() }
                                )
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: viewModel.selectedSpot != nil)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.selectedBuoy != nil)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // Navigate to detailed spot view
    private func navigateToSpotDetails(_ spot: SpotData) {
        // For now, we'll just clear the selection
        // In a full implementation, this would navigate to the spot detail view
        // and potentially change the tab or push a new view
        viewModel.clearSelection()
        
        // TODO: Implement navigation to spot detail view
        // This could involve:
        // 1. Changing to the Spots tab
        // 2. Pushing a detail view
        // 3. Using a navigation coordinator
        print("Navigate to spot details for: \(spot.name)")
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}
