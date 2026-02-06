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
                surfReportService: dependencies.surfReportService,
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
                        RecentReportCard(report: latestReport)
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
                                    MatchingReportCard(report: report)
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
                SurfConditionsGrid(aiPrediction: aiPrediction)

                // Weather conditions and additional info grids
                WeatherConditionsGrid()
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
                surfReportService: dependencies.surfReportService
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
}

#Preview {
    let dependencies = AppDependencies()
    LiveSpotView(spotId: "test", dependencies: dependencies)
        .environmentObject(dependencies.dataStore)
}
