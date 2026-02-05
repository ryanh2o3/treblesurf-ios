import SwiftUI
import MapKit

struct MapContentView: View {
    let viewModel: MapViewModel
    @Binding var region: MKCoordinateRegion
    
    var body: some View {
        Map(position: .constant(.region(region))) {
            // Add spot annotations
            ForEach(viewModel.surfSpots) { spot in
                Annotation(
                    spot.name,
                    coordinate: viewModel.coordinateForSpot(spot),
                    anchor: .bottom
                ) {
                    SpotMarker(
                        spot: spot,
                        isSelected: viewModel.selectedSpot?.id == spot.id,
                        onTap: {
                            // Zoom in and center on the spot
                            withAnimation(.easeInOut(duration: 0.5)) {
                                region = viewModel.getZoomedRegionForSpot(spot)
                            }
                            viewModel.selectSpot(spot)
                        }
                    )
                }
            }
            
            // Add buoy annotations
            ForEach(viewModel.buoys, id: \.name) { buoy in
                Annotation(
                    buoy.name,
                    coordinate: viewModel.coordinateForBuoy(buoy),
                    anchor: .bottom
                ) {
                    BuoyMarker(
                        buoy: buoy,
                        isSelected: viewModel.selectedBuoy?.name == buoy.name,
                        onTap: {
                            // Zoom in and center on the buoy
                            withAnimation(.easeInOut(duration: 0.5)) {
                                region = viewModel.getZoomedRegionForBuoy(buoy)
                            }
                            viewModel.selectBuoy(buoy)
                        }
                    )
                }
            }
        }
    }
}

struct MapContentView_Previews: PreviewProvider {
    static var previews: some View {
        let dependencies = AppDependencies()
        let viewModel = MapViewModel(
            dataStore: dependencies.dataStore,
            apiClient: dependencies.apiClient
        )
        MapContentView(
            viewModel: viewModel,
            region: .constant(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 55.186844, longitude: -7.59785),
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            ))
        )
    }
}
