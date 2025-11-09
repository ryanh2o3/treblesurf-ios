import SwiftUI
import AVKit

struct SpotReportsListView: View {
    let spotId: String
    let spotName: String
    
    @StateObject private var viewModel: SpotReportsListViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(spotId: String, spotName: String) {
        self.spotId = spotId
        self.spotName = spotName
        self._viewModel = StateObject(wrappedValue: SpotReportsListViewModel(spotId: spotId))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading && viewModel.reports.isEmpty {
                    // Initial loading state
                    ProgressView("Loading reports...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if viewModel.reports.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("No Reports Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Be the first to report conditions at \(spotName)!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    // Report list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.reports) { report in
                                ReportCardView(report: report)
                                    .padding(.horizontal)
                            }
                            
                            // Load more indicator
                            if viewModel.hasMore {
                                HStack {
                                    Spacer()
                                    if viewModel.isLoadingMore {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Button("Load More") {
                                            viewModel.loadMoreReports()
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    }
                                    Spacer()
                                }
                                .padding()
                            }
                        }
                        .padding(.vertical)
                    }
                }
                
                // Error alert
                if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .padding()
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle("Reports: \(spotName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadInitialReports()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
}

// MARK: - Report Card View
struct ReportCardView: View {
    @ObservedObject var report: SurfReport
    @State private var isLoadingImage = false
    @State private var isLoadingVideo = false
    @State private var showingVideoPlayer = false
    @State private var videoURL: URL?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with reporter and time
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.reporter)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(report.time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Media type badge
                if let mediaType = report.mediaType {
                    Image(systemName: mediaType == "video" ? "video.fill" : "photo.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Media content
            if let imageKey = report.imageKey, !imageKey.isEmpty {
                mediaView
            } else if let videoKey = report.videoKey, !videoKey.isEmpty {
                mediaView
            }
            
            // Conditions
            VStack(alignment: .leading, spacing: 8) {
                conditionRow(label: "Surf Size", value: formatCondition(report.surfSize))
                conditionRow(label: "Quality", value: formatCondition(report.quality))
                conditionRow(label: "Wind", value: "\(formatCondition(report.windDirection)) \(formatCondition(report.windAmount))")
                conditionRow(label: "Consistency", value: formatCondition(report.consistency))
                conditionRow(label: "Messiness", value: formatCondition(report.messiness))
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            loadMediaIfNeeded()
        }
    }
    
    @ViewBuilder
    private var mediaView: some View {
        ZStack {
            if let imageData = report.imageData,
               let data = Data(base64Encoded: imageData),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(8)
            } else if let videoKey = report.videoKey, !videoKey.isEmpty {
                // Video thumbnail or placeholder
                ZStack {
                    if let thumbnail = report.videoThumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(8)
                    }
                    
                    // Play button overlay
                    Button(action: {
                        loadAndPlayVideo()
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    
                    if isLoadingVideo {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
            } else if isLoadingImage {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
        }
        .sheet(isPresented: $showingVideoPlayer) {
            if let videoURL = videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .ignoresSafeArea()
            }
        }
    }
    
    private func conditionRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
    }
    
    private func formatCondition(_ value: String) -> String {
        if value.isEmpty {
            return "N/A"
        }
        // Convert snake-case or kebab-case to title case
        return value
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    private func loadMediaIfNeeded() {
        // Load image if needed
        if let imageKey = report.imageKey, !imageKey.isEmpty, report.imageData == nil {
            isLoadingImage = true
            APIClient.shared.getReportImage(key: imageKey) { result in
                DispatchQueue.main.async {
                    isLoadingImage = false
                    switch result {
                    case .success(let response):
                        report.imageData = response.imageData
                    case .failure(let error):
                        print("Failed to load image: \(error)")
                    }
                }
            }
        }
    }
    
    private func loadAndPlayVideo() {
        guard let videoKey = report.videoKey, !videoKey.isEmpty else { return }
        
        isLoadingVideo = true
        APIClient.shared.getVideoViewURL(key: videoKey) { result in
            DispatchQueue.main.async {
                self.isLoadingVideo = false
                switch result {
                case .success(let response):
                    if let viewURLString = response.viewURL,
                       let url = URL(string: viewURLString) {
                        self.videoURL = url
                        self.showingVideoPlayer = true
                    }
                case .failure(let error):
                    print("Failed to generate video view URL: \(error)")
                }
            }
        }
    }
}

#Preview {
    SpotReportsListView(spotId: "Ireland#Donegal#Tullan Strand", spotName: "Tullan Strand")
}

