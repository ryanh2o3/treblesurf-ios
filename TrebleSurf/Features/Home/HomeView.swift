import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date header
                    Text(viewModel.formattedCurrentDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Current conditions card
                    if let condition = viewModel.currentCondition {
                        currentConditionView(condition)
                    }
                    
                    // Featured spots section
                    VStack(alignment: .leading) {
                        Text("Featured Spots")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(viewModel.featuredSpots) { spot in
                                    featuredSpotCard(spot)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Recent reports section
                    VStack(alignment: .leading) {
                        Text("Recent Reports")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.recentReports) { report in
                            reportRow(report)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("TrebleSurf")
            .onAppear {
                viewModel.loadData()
            }
        }
    }
    
    private func currentConditionView(_ condition: CurrentCondition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Conditions")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text(condition.waveHeight)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Wave Height")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("\(condition.windDirection) \(condition.windSpeed)")
                        .font(.title3)
                    Text("Wind")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text(condition.temperature)
                        .font(.title3)
                    Text("Temp")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(condition.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private func featuredSpotCard(_ spot: FeaturedSpot) -> some View {
        VStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1.5, contentMode: .fit)
                .cornerRadius(8)
                .overlay(
                    Text("Image")
                        .foregroundColor(.secondary)
                )
            
            Text(spot.name)
                .font(.headline)
            
            HStack {
                Text(spot.waveHeight)
                Spacer()
                Text(spot.quality)
            }
            .font(.subheadline)
            
            Text(spot.distance)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 160)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func reportRow(_ report: SurfReport) -> some View {
        HStack {
            if let imageData = report.imageData,
                       let data = Data(base64Encoded: imageData),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .overlay(
                                Text("Photo")
                                    .foregroundColor(.secondary)
                            )
                    }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(report.countryRegionSpot)
                    .font(.headline)
                
                HStack {
                    Text(report.surfSize)
                    Text("•")
                    Text(report.quality)
                }
                .font(.subheadline)
                
                Text(report.time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .onReceive(report.objectWillChange) { _ in
                // Force UI update when imageData changes
            }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
