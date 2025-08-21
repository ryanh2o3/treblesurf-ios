// LiveSpotView.swift
import SwiftUI

struct LiveSpotView: View {
    @EnvironmentObject var dataStore: DataStore
    var spotId: String
    var refreshTrigger: Bool = false // Add refresh trigger
    @State private var spotImage: Image? = nil
    @StateObject private var viewModel = LiveSpotViewModel()
    @State private var selectedReport: SurfReport?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Current conditions header
                VStack(alignment: .leading, spacing: 6) {
                    
                    if let spotImage = spotImage {
                        spotImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 6)
                
                // Recent surf report card
                VStack(alignment: .leading, spacing: 6) {
                    // Title and report buttons on same line
                    HStack {
                        Text("Recent Report")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Report submission buttons
                        HStack(spacing: 8) {
                            Button(action: {
                                viewModel.showQuickForm = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                    Image(systemName: "camera.circle.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                                viewModel.showReportForm = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    Image(systemName: "doc.text")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading reports...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 6)
                    } else if !viewModel.recentReports.isEmpty {
                        let latestReport = viewModel.recentReports.first!
                        recentReportCard(latestReport)
                            .onTapGesture {
                                selectedReport = latestReport
                            }
                    } else if let errorMessage = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 6)
                    } else {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.secondary)
                            Text("No recent reports")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 6)
                    }
                }
                
                // Surf conditions grid
                VStack(alignment: .leading, spacing: 6) {
                    Text("Surf Conditions")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ReadingCard(
                            title: "Surf Size",
                            value: String(format: "%.1f", dataStore.currentConditions.surfSize),
                            unit: "m",
                            icon: "water.waves"
                        )
                        
                        ReadingCard(
                            title: "Surf Messiness",
                            value: dataStore.currentConditions.surfMessiness,
                            unit: "",
                            icon: "water.waves.and.arrow.up"
                        )
                        
                        ReadingCard(
                            title: "Relative Wind",
                            value: dataStore.currentConditions.formattedRelativeWindDirection,
                            unit: "",
                            icon: "arrow.up.left.and.arrow.down.right"
                        )
                        
                        ReadingCard(
                            title: "Swell Period",
                            value: String(format: "%.0f", dataStore.currentConditions.swellPeriod),
                            unit: "sec",
                            icon: "timer"
                        )
                        
                        ReadingCard(
                            title: "Swell Direction",
                            value: String(format: "%.0f", dataStore.currentConditions.swellDirection),
                            unit: "°",
                            icon: "swellDirection"
                        )
                        
                        ReadingCard(
                            title: "Wave Energy",
                            value: String(format: "%.0f", dataStore.currentConditions.waveEnergy),
                            unit: "kJ/m²",
                            icon: "bolt"
                        )
                    }
                }
                .padding(.horizontal, 6)
                
                // Weather conditions grid
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weather Conditions")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ReadingCard(
                            title: "Wind Speed",
                            value: String(format: "%.1f", dataStore.currentConditions.windSpeed),
                            unit: "km/h",
                            icon: "wind"
                        )
                        
                        ReadingCard(
                            title: "Wind Direction",
                            value: String(format: "%.0f", dataStore.currentConditions.windDirection),
                            unit: "°",
                            icon: "arrow.up.right"
                        )
                        
                        ReadingCard(
                            title: "Temperature",
                            value: String(format: "%.1f", dataStore.currentConditions.temperature),
                            unit: "°C",
                            icon: "thermometer"
                        )
                        
                        ReadingCard(
                            title: "Water Temp",
                            value: String(format: "%.1f", dataStore.currentConditions.waterTemperature),
                            unit: "°C",
                            icon: "thermometer.sun"
                        )
                        
                        ReadingCard(
                            title: "Humidity",
                            value: String(format: "%.0f", dataStore.currentConditions.humidity),
                            unit: "%",
                            icon: "humidity"
                        )
                        
                        ReadingCard(
                            title: "Pressure",
                            value: String(format: "%.0f", dataStore.currentConditions.pressure),
                            unit: "hPa",
                            icon: "gauge"
                        )
                    }
                }
                .padding(.horizontal, 6)
                
                // Additional conditions
                VStack(alignment: .leading, spacing: 6) {
                    Text("Additional Info")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ReadingCard(
                            title: "Precipitation",
                            value: String(format: "%.1f", dataStore.currentConditions.precipitation),
                            unit: "mm",
                            icon: "cloud.rain"
                        )
                        
                        ReadingCard(
                            title: "Swell Height",
                            value: String(format: "%.1f", dataStore.currentConditions.swellHeight),
                            unit: "m",
                            icon: "water.waves"
                        )
                        
                        ReadingCard(
                            title: "Direction Quality",
                            value: String(format: "%.1f", dataStore.currentConditions.directionQuality),
                            unit: "",
                            icon: "star"
                        )
                        
                        ReadingCard(
                            title: "Last Updated",
                            value: dataStore.relativeTimeDisplay,
                            unit: "",
                            icon: "clock"
                        )
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .refreshable {
            // Refresh current conditions
            dataStore.fetchConditions(for: spotId) { _ in }
            
            // Refresh surf reports
            viewModel.refreshSurfReports(for: spotId)
        }
        .task {
            // Trigger data fetch when view appears
            dataStore.fetchConditions(for: spotId) { success in
                if !success {
                    // Handle error if needed
                }
            }
            
            // Fetch surf reports for this spot
            viewModel.fetchSurfReports(for: spotId)
            
            // Fetch spot image
//            dataStore.fetchSpotImage(for: spotId) { image in
//                self.spotImage = image
//            }
        }
        .onChange(of: refreshTrigger) { _, newValue in
            // Refresh data when refresh trigger changes
            dataStore.fetchConditions(for: spotId) { _ in }
            viewModel.refreshSurfReports(for: spotId)
        }
        .sheet(item: $selectedReport) { report in
            SurfReportDetailView(report: report, backButtonText: "Back to \(viewModel.getSpotName(from: spotId))")
        }
        .sheet(isPresented: $viewModel.showReportForm) {
            SurfReportSubmissionView(spotId: spotId, spotName: viewModel.getSpotName(from: spotId))
        }
        .sheet(isPresented: $viewModel.showQuickForm) {
            QuickPhotoReportView(spotId: spotId, spotName: viewModel.getSpotName(from: spotId))
        }
    }
    
    private func recentReportCard(_ report: SurfReport) -> some View {
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
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    LiveSpotView(spotId: "test")
        .environmentObject(DataStore())
}
