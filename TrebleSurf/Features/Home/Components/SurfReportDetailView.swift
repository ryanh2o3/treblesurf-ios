import SwiftUI
import AVKit
import UIKit
import Foundation

// MARK: - Surf Report Detail View
struct SurfReportDetailView: View {
    let report: SurfReport
    let backButtonText: String
    private let surfReportService: SurfReportService
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingVideoPlayer = false
    @State private var videoURL: URL?
    @State private var videoViewURL: String?
    @State private var isLoadingVideo = false
    @State private var cachedVideoURL: URL?
    
    init(report: SurfReport, backButtonText: String = "Back to Reports", surfReportService: SurfReportService) {
        self.report = report
        self.backButtonText = backButtonText
        self.surfReportService = surfReportService
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
                    
                    // Main media (image or video thumbnail)
                    if let imageData = report.imageData,
                       let data = Data(base64Encoded: imageData),
                       let uiImage = UIImage(data: data) {
                        // Show image or video thumbnail
                        ZStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(16)
                            
                            // Show play button or loading indicator if this is a video
                            if let videoKey = report.videoKey, !videoKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                if isLoadingVideo {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                        .background(Color.black.opacity(0.3))
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.3))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .onTapGesture {
                            // If this is a video, play it
                            if let videoKey = report.videoKey, !videoKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                if let cachedURL = cachedVideoURL {
                                    playVideoFromCachedURL(cachedURL)
                                } else if let viewURL = videoViewURL {
                                    playVideoFromURL(viewURL)
                                } else if !isLoadingVideo {
                                    loadVideoViewURL()
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(1.5, contentMode: .fit)
                            .cornerRadius(16)
                            .overlay(
                                VStack {
                                    Image(systemName: mediaTypeIcon(for: report.mediaType))
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text(mediaTypeText(for: report.mediaType))
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
                    
                    // Matching Condition Data (if available)
                    if let combinedSimilarity = report.combinedSimilarity,
                       let matchedBuoy = report.matchedBuoy {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Matching Conditions at Report Time")
                                    .font(.headline)
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("\(Int(combinedSimilarity * 100))% match")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                            
                            Text("Based on \(matchedBuoy) buoy data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                if let waveHeight = report.historicalBuoyWaveHeight {
                                    ConditionCard(title: "Buoy Wave Height", value: String(format: "%.1fm", waveHeight), icon: "water.waves", color: .blue)
                                }
                                if let waveDir = report.historicalBuoyWaveDirection {
                                    ConditionCard(title: "Buoy Wave Dir", value: String(format: "%.0f°", waveDir), icon: "arrow.up.right", color: .blue)
                                }
                                if let period = report.historicalBuoyPeriod {
                                    ConditionCard(title: "Buoy Period", value: String(format: "%.0fs", period), icon: "timer", color: .blue)
                                }
                                if let windSpeed = report.historicalWindSpeed {
                                    ConditionCard(title: "Wind Speed", value: String(format: "%.1f km/h", windSpeed), icon: "wind", color: .cyan)
                                }
                                if let windDir = report.historicalWindDirection {
                                    ConditionCard(title: "Wind Dir", value: String(format: "%.0f°", windDir), icon: "arrow.up.right", color: .orange)
                                }
                                if let travelTime = report.travelTimeHours {
                                    ConditionCard(title: "Swell Travel Time", value: String(format: "%.1fh", travelTime), icon: "clock", color: .purple)
                                }
                            }
                            .padding(.horizontal)
                            
                            if let buoySim = report.buoySimilarity, let windSim = report.windSimilarity {
                                HStack(spacing: 16) {
                                    VStack {
                                        Text("Buoy Match")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(Int(buoySim * 100))%")
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    }
                                    Divider()
                                    VStack {
                                        Text("Wind Match")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(Int(windSim * 100))%")
                                            .font(.headline)
                                            .foregroundColor(.cyan)
                                    }
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
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
        .onAppear {
            // Clean up old cached videos
            cleanupOldCachedVideos()
            
            // Check for cached video first, then load if needed
            if let videoKey = report.videoKey, !videoKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                checkForCachedVideo()
                if videoViewURL == nil && cachedVideoURL == nil {
                    loadVideoViewURL()
                }
            }
        }
        .sheet(isPresented: $showingVideoPlayer) {
            if let videoURL = videoURL {
                let player = AVPlayer(url: videoURL)
                VideoPlayer(player: player)
                    .onAppear {
                        // Auto-play the video when the player appears
                        player.play()
                    }
                    .onDisappear {
                        // Clean up video URL when sheet is dismissed
                        self.videoURL = nil
                    }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func checkForCachedVideo() {
        guard let videoKey = report.videoKey else { return }
        
        let cacheDirectory = getVideoCacheDirectory()
        let fileName = "\(videoKey.replacingOccurrences(of: "/", with: "_")).mp4"
        let cachedURL = cacheDirectory.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            self.cachedVideoURL = cachedURL
        }
    }
    
    private func getVideoCacheDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cacheDirectory = documentsPath.appendingPathComponent("VideoCache")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        return cacheDirectory
    }
    
    private func loadVideoViewURL() {
        guard let videoKey = report.videoKey else { return }
        
        isLoadingVideo = true
        
        Task {
            do {
                let viewResponse = try await surfReportService.getVideoViewURL(key: videoKey)
                self.isLoadingVideo = false
                if let viewURL = viewResponse.viewURL {
                    self.videoViewURL = viewURL

                    // Download and cache the video
                    self.downloadAndCacheVideo(from: viewURL, videoKey: videoKey)
                }
            } catch {
                self.isLoadingVideo = false
            }
        }
    }
    
    private func downloadAndCacheVideo(from urlString: String, videoKey: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        
        let cacheDirectory = getVideoCacheDirectory()
        let fileName = "\(videoKey.replacingOccurrences(of: "/", with: "_")).mp4"
        let cachedURL = cacheDirectory.appendingPathComponent(fileName)
        
        // Download video in background
        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }

                guard let tempURL = tempURL else {
                    return
                }

                do {
                    // Move downloaded file to cache directory
                    if FileManager.default.fileExists(atPath: cachedURL.path) {
                        try FileManager.default.removeItem(at: cachedURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: cachedURL)

                    self.cachedVideoURL = cachedURL
                } catch {
                    // Video caching failed
                }
            }
        }.resume()
    }
    
    private func playVideoFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }

        self.videoURL = url
        showingVideoPlayer = true
    }
    
    private func playVideoFromCachedURL(_ cachedURL: URL) {
        self.videoURL = cachedURL
        showingVideoPlayer = true
    }
    
    private func cleanupOldCachedVideos() {
        let cacheDirectory = getVideoCacheDirectory()
        let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            let now = Date()
            
            for file in files {
                if let creationDate = try file.resourceValues(forKeys: [.creationDateKey]).creationDate {
                    if now.timeIntervalSince(creationDate) > maxCacheAge {
                        try FileManager.default.removeItem(at: file)
                    }
                }
            }
        } catch {
            // Cleanup of cached videos failed
        }
    }
    
    private func playVideoFromBase64(_ base64String: String) {
        guard let videoData = Data(base64Encoded: base64String) else {
            return
        }
        
        // Create a temporary file for the video data
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileName = "temp_video_\(UUID().uuidString).mov"
        let tempURL = tempDirectory.appendingPathComponent(tempFileName)
        
        do {
            try videoData.write(to: tempURL)
            self.videoURL = tempURL
            showingVideoPlayer = true
        } catch {
            // Failed to write video data to temporary file
        }
    }
    
    private func mediaTypeIcon(for mediaType: String?) -> String {
        switch mediaType?.lowercased() {
        case "video":
            return "video"
        case "image":
            return "photo"
        default:
            return "photo"
        }
    }
    
    private func mediaTypeText(for mediaType: String?) -> String {
        switch mediaType?.lowercased() {
        case "video":
            return "Video"
        case "image":
            return "Photo"
        default:
            return "Photo"
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

struct OptionalDetailRow: View {
    let label: String
    let value: String?
    
    var body: some View {
        if let value = value {
            DetailRow(label: label, value: value)
        }
    }
}
