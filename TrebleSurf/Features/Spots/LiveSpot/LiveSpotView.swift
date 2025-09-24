// LiveSpotView.swift
import SwiftUI
import AVKit

struct LiveSpotView: View {
    @EnvironmentObject var dataStore: DataStore
    var spotId: String
    var refreshTrigger: Bool = false // Add refresh trigger
    var spotImage: Image? = nil // This will be nil since parent handles the image
    @StateObject private var viewModel = LiveSpotViewModel()
    @State private var selectedReport: SurfReport?
    @State private var showingVideoPlayer = false
    @State private var videoURL: URL?
    @State private var showAIPrediction = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Current conditions header - removed duplicate spot image
                VStack(alignment: .leading, spacing: 6) {
                    // Content will be populated by parent view
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
                                // If the report has a video key, we'll handle video playback in the detail view
                                // The detail view will fetch the presigned URL for video viewing
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
                
                // AI Prediction toggle
                AIPredictionToggle(isEnabled: $showAIPrediction, spotId: spotId)
                    .padding(.horizontal, 6)
                
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
        .sheet(isPresented: $showingVideoPlayer) {
            if let videoURL = videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .ignoresSafeArea()
                    .onDisappear {
                        // Clean up temporary file when video player is dismissed
                        try? FileManager.default.removeItem(at: videoURL)
                    }
            }
        }
    }
    
    private func recentReportCard(_ report: SurfReport) -> some View {
        HStack {
            // Media preview - show image, video thumbnail, or placeholder
            Group {
                if let imageData = report.imageData,
                   let data = Data(base64Encoded: imageData),
                   let uiImage = UIImage(data: data) {
                    // Show image or video thumbnail
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)
                        
                        // Show play button if this report has a meaningful video key
                        if let videoKey = report.videoKey, !videoKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                } else if let videoThumbnail = report.videoThumbnail {
                    // Show video thumbnail with play button
                    ZStack {
                        Image(uiImage: videoThumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)
                        
                        // Play button overlay
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                } else {
                    // Show placeholder based on media type
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            VStack(spacing: 2) {
                                Image(systemName: mediaTypeIcon(for: report.mediaType))
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                Text(mediaTypeText(for: report.mediaType))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        )
                }
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
    
    // MARK: - Helper Functions
    
    private func mediaTypeIcon(for mediaType: String?) -> String {
        switch mediaType?.lowercased() {
        case "image":
            return "photo"
        case "video":
            return "video"
        case "both":
            return "photo.on.rectangle"
        default:
            return "photo"
        }
    }
    
    private func mediaTypeText(for mediaType: String?) -> String {
        switch mediaType?.lowercased() {
        case "image":
            return "Photo"
        case "video":
            return "Video"
        case "both":
            return "Media"
        default:
            return "Photo"
        }
    }
}

#Preview {
    LiveSpotView(spotId: "test")
        .environmentObject(DataStore())
}
