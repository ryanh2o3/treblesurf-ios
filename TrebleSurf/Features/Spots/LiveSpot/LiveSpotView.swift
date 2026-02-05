// LiveSpotView.swift
import SwiftUI
import AVKit

struct LiveSpotView: View {
    @EnvironmentObject var dataStore: DataStore
    var spotId: String
    var refreshTrigger: Bool = false // Add refresh trigger
    var spotImage: Image? = nil // This will be nil since parent handles the image
    var aiPrediction: SwellPredictionEntry? = nil // AI prediction passed from parent
    @StateObject private var viewModel: LiveSpotViewModel
    private let dependencies: AppDependencies
    @State private var selectedReport: SurfReport?
    @State private var showingVideoPlayer = false
    @State private var videoURL: URL?
    @State private var showingAllReports = false
    
    init(
        spotId: String,
        refreshTrigger: Bool = false,
        spotImage: Image? = nil,
        aiPrediction: SwellPredictionEntry? = nil,
        dependencies: AppDependencies
    ) {
        self.spotId = spotId
        self.refreshTrigger = refreshTrigger
        self.spotImage = spotImage
        self.aiPrediction = aiPrediction
        self.dependencies = dependencies
        _viewModel = StateObject(
            wrappedValue: LiveSpotViewModel(
                apiClient: dependencies.apiClient,
                imageCache: dependencies.imageCache,
                errorHandler: dependencies.errorHandler,
                logger: dependencies.errorLogger
            )
        )
    }

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
                        
                        // View All Reports button
                        Button(action: {
                            showingAllReports = true
                        }) {
                            HStack(spacing: 4) {
                                Text("View All")
                                    .font(.subheadline)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                        
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
                    } else if let errorPresentation = viewModel.errorPresentation {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(errorPresentation.message)
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
                
                // Past matching condition reports section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Past Matching Condition Reports")
                        .font(.headline)
                        .padding(.horizontal, 6)
                    
                    if viewModel.isLoadingMatchingReports {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading matching reports...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 6)
                    } else if !viewModel.matchingConditionReports.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.matchingConditionReports.prefix(5), id: \.id) { report in
                                    matchingReportCard(report)
                                        .onTapGesture {
                                            selectedReport = report
                                        }
                                }
                            }
                            .padding(.horizontal, 6)
                        }
                    } else if let errorPresentation = viewModel.errorPresentation {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(errorPresentation.message)
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
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text("No matching reports from the past")
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
                    HStack {
                        Text("Surf Conditions")
                            .font(.headline)
                        
                        Spacer()
                        
                        // ML indicator
                        if aiPrediction != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "brain.head.profile")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                                Text("powered by ML")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        // Surf Size - use AI prediction if available
                        ReadingCard(
                            title: aiPrediction != nil ? "Surf Size (ML)" : "Surf Size",
                            value: aiPrediction != nil ? String(format: "%.1f", aiPrediction!.surfSize) : String(format: "%.1f", dataStore.currentConditions.surfSize),
                            unit: "m",
                            icon: "water.waves",
                            iconColor: aiPrediction != nil ? .purple : .blue
                        )
                        
                        // Surf Messiness - keep current conditions
                        ReadingCard(
                            title: "Surf Messiness",
                            value: dataStore.currentConditions.surfMessiness,
                            unit: "",
                            icon: "water.waves.and.arrow.up"
                        )
                        
                        // Relative Wind - keep current conditions
                        ReadingCard(
                            title: "Relative Wind",
                            value: dataStore.currentConditions.formattedRelativeWindDirection,
                            unit: "",
                            icon: "arrow.up.left.and.arrow.down.right"
                        )
                        
                        // Swell Period - use AI prediction if available
                        ReadingCard(
                            title: aiPrediction != nil ? "Swell Period (ML)" : "Swell Period",
                            value: aiPrediction != nil ? String(format: "%.0f", aiPrediction!.predictedPeriod) : String(format: "%.0f", dataStore.currentConditions.swellPeriod),
                            unit: "sec",
                            icon: "timer",
                            iconColor: aiPrediction != nil ? .purple : .blue
                        )
                        
                        // Swell Direction - use AI prediction if available
                        ReadingCard(
                            title: aiPrediction != nil ? "Swell Direction (ML)" : "Swell Direction",
                            value: aiPrediction != nil ? String(format: "%.0f", aiPrediction!.predictedDirection) : String(format: "%.0f", dataStore.currentConditions.swellDirection),
                            unit: "°",
                            icon: "swellDirection",
                            iconColor: aiPrediction != nil ? .purple : .blue
                        )
                        
                        // Wave Energy - keep current conditions
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
            _ = await dataStore.fetchConditions(for: spotId)
            
            // Refresh surf reports
            viewModel.refreshSurfReports(for: spotId)
            
            // Refresh matching condition reports
            viewModel.refreshMatchingConditionReports(for: spotId)
        }
        .task {
            // Trigger data fetch when view appears
            _ = await dataStore.fetchConditions(for: spotId)
            
            // Fetch surf reports for this spot
            viewModel.fetchSurfReports(for: spotId)
            
            // Fetch matching condition reports for this spot
            viewModel.fetchMatchingConditionReports(for: spotId)
        }
        .onChange(of: refreshTrigger) { _, newValue in
            // Refresh data when refresh trigger changes
            Task {
                _ = await dataStore.fetchConditions(for: spotId)
                viewModel.refreshSurfReports(for: spotId)
                viewModel.refreshMatchingConditionReports(for: spotId)
            }
        }
        .sheet(item: $selectedReport) { report in
            SurfReportDetailView(
                report: report,
                backButtonText: "Back to \(viewModel.getSpotName(from: spotId))",
                apiClient: dependencies.apiClient
            )
        }
        .sheet(isPresented: $viewModel.showReportForm) {
            SurfReportSubmissionView(
                spotId: spotId,
                spotName: viewModel.getSpotName(from: spotId),
                dependencies: dependencies
            )
        }
        .sheet(isPresented: $viewModel.showQuickForm) {
            QuickPhotoReportView(
                spotId: spotId,
                spotName: viewModel.getSpotName(from: spotId),
                dependencies: dependencies
            )
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
        .sheet(isPresented: $showingAllReports) {
            SpotReportsListView(
                spotId: spotId,
                spotName: viewModel.getSpotName(from: spotId),
                dependencies: dependencies
            )
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
    
    private func matchingReportCard(_ report: SurfReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Media preview - show image, video thumbnail, or placeholder
            ZStack(alignment: .topTrailing) {
                Group {
                    if let imageData = report.imageData,
                       let data = Data(base64Encoded: imageData),
                       let uiImage = UIImage(data: data) {
                        // Show image or video thumbnail
                        ZStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 140, height: 140)
                                .clipped()
                                .cornerRadius(8)
                            
                            // Show play button if this report has a meaningful video key
                            if let videoKey = report.videoKey, !videoKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 30))
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
                                .frame(width: 140, height: 140)
                                .clipped()
                                .cornerRadius(8)
                            
                            // Play button overlay
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                    } else {
                        // Show placeholder based on media type
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 140, height: 140)
                            .cornerRadius(8)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: mediaTypeIcon(for: report.mediaType))
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                    Text(mediaTypeText(for: report.mediaType))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                }
                
                // Show similarity badge if available
                if let similarity = report.combinedSimilarity {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                        Text("\(Int(similarity * 100))%")
                            .font(.system(size: 10))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green)
                    .cornerRadius(8)
                    .padding(6)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(report.surfSize)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("•")
                    Text(report.quality)
                        .font(.subheadline)
                }
                .foregroundColor(.primary)
                
                Text(report.time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .frame(width: 156)
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
    let dependencies = AppDependencies()
    LiveSpotView(spotId: "test", dependencies: dependencies)
        .environmentObject(dependencies.dataStore)
}
