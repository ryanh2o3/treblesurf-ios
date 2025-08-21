import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel = HomeViewModel()
    @State private var selectedReport: SurfReport?
    
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
                                .onTapGesture {
                                    selectedReport = report
                                }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("TrebleSurf")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ThemeToggleButton()
                }
            }
            .onAppear {
                viewModel.loadData()
            }
            .sheet(item: $selectedReport) { report in
                SurfReportDetailView(report: report)
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

// MARK: - Surf Report Detail View
struct SurfReportDetailView: View {
    let report: SurfReport
    let backButtonText: String
    @Environment(\.dismiss) private var dismiss
    
    init(report: SurfReport, backButtonText: String = "Back to Reports") {
        self.report = report
        self.backButtonText = backButtonText
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with back button
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                Text(backButtonText)
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Main image
                    if let imageData = report.imageData,
                       let data = Data(base64Encoded: imageData),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(16)
                            .padding(.horizontal)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(1.5, contentMode: .fit)
                            .cornerRadius(16)
                            .overlay(
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("No Photo Available")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                            .padding(.horizontal)
                    }
                    
                    // Spot information
                    VStack(alignment: .leading, spacing: 12) {
                        Text(report.countryRegionSpot)
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        Text("Reported by \(report.reporter)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Text("Spotted \(report.time)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    // Surf conditions grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Surf Conditions")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ConditionCard(title: "Wave Size", value: report.surfSize, icon: "water.waves", color: .blue)
                            ConditionCard(title: "Quality", value: report.quality, icon: "star.fill", color: .yellow)
                            ConditionCard(title: "Consistency", value: report.consistency, icon: "repeat", color: .green)
                            ConditionCard(title: "Messiness", value: report.messiness, icon: "leaf", color: .brown)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Wind conditions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Wind Conditions")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ConditionCard(title: "Direction", value: report.windDirection, icon: "arrow.up.right", color: .orange)
                            ConditionCard(title: "Strength", value: report.windAmount, icon: "wind", color: .cyan)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Additional details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Report Details")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(label: "Reporter", value: report.reporter)
                            DetailRow(label: "Email", value: report.userEmail)
                            DetailRow(label: "Date Reported", value: report.dateReported)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Surf Report")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Supporting Views
struct ConditionCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
