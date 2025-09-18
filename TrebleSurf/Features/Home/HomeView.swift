import SwiftUI
import AVKit
import Foundation

struct HomeView: View {
    @ObservedObject var viewModel = HomeViewModel()
    @State private var selectedReport: SurfReport?
    @State private var showingVideoPlayer = false
    @State private var videoURL: URL?
    
    var body: some View {
        NavigationView {
            MainLayout {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    // Header with title and theme toggle
                    HStack {
                        Text("Treble Surf")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        ThemeToggleButton()
                    }
                    .padding(.horizontal)
                    
                    // Current conditions card
                    if viewModel.isLoadingConditions {
                        currentConditionLoadingView()
                    } else if let condition = viewModel.currentCondition {
                        currentConditionView(condition)
                    }
                    
                    // Recent reports section (replacing featured spots)
                    VStack(alignment: .leading) {
                        Text("Recent Reports")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 15) {
                                ForEach(viewModel.recentReports) { report in
                                    reportCard(report)
                                        .onTapGesture {
                                            selectedReport = report
                                            // If the report has video data, prepare for video playback
                                            if let videoData = report.videoData,
                                               let data = Data(base64Encoded: videoData) {
                                                // Create temporary file for video playback
                                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video_\(UUID().uuidString).mp4")
                                                do {
                                                    try data.write(to: tempURL)
                                                    videoURL = tempURL
                                                    showingVideoPlayer = true
                                                } catch {
                                                    print("Failed to create temporary video file: \(error)")
                                                }
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Weather buoys section
                    VStack(alignment: .leading) {
                        Text("Weather Buoys")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(viewModel.weatherBuoys) { buoy in
                                weatherBuoyCard(buoy)
                            }
                        }
                        .padding(.horizontal)
                    }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.refreshData()
                }
                            .navigationBarHidden(true)

                .onAppear {
                    viewModel.loadData()
                }
                .sheet(item: $selectedReport) { report in
                    SurfReportDetailView(report: report)
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
        }
    }
    
    private func currentConditionLoadingView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Conditions")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    Text("Wave Height")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.title3)
                    }
                    Text("Wind")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.title3)
                    }
                    Text("Temp")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Loading conditions for Ballyhiernan...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
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
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
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
    
    private func reportCard(_ report: SurfReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media section - show image, video thumbnail, or placeholder
            if let imageData = report.imageData,
               let data = Data(base64Encoded: imageData),
               let uiImage = UIImage(data: data) {
                // Show image
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 100)
                    .clipped()
            } else if let videoThumbnail = report.videoThumbnail {
                // Show video thumbnail with play button
                ZStack {
                    Image(uiImage: videoThumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 100)
                        .clipped()
                    
                    // Play button overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            } else {
                // Show placeholder based on media type
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 160, height: 100)
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
            
            // Content section
            VStack(alignment: .leading, spacing: 4) {
                Text(report.countryRegionSpot)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(report.surfSize)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(report.quality)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(report.time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .frame(width: 160, height: 180)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onReceive(report.objectWillChange) { _ in
            // Force UI update when imageData changes
        }
    }
    
    private func weatherBuoyCard(_ buoy: WeatherBuoy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with buoy name and loading indicator
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "water.waves")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        )
                    
                    Text(buoy.name)
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                if buoy.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Data grid
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(buoy.waveHeight)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Wave Height")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(buoy.wavePeriod)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Period")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(buoy.waveDirection)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Direction")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(buoy.waterTemperature)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Water")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
                            OptionalDetailRow(label: "Email", value: report.userEmail)
                            DetailRow(label: "Date Reported", value: report.formattedDateReported)
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
    
    // MARK: - Helper Functions
    
}

struct OptionalDetailRow: View {
    let label: String
    let value: String?
    
    var body: some View {
        if let value = value {
            DetailRow(label: label, value: value)
        }
    }
}
