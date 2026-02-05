import SwiftUI
import AVKit
import Foundation

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var selectedReport: SurfReport?
    @State private var showingVideoPlayer = false
    @State private var videoURL: URL?
    private let apiClient: APIClientProtocol
    
    init(dependencies: AppDependencies) {
        self.apiClient = dependencies.apiClient
        _viewModel = StateObject(
            wrappedValue: HomeViewModel(
                config: dependencies.config,
                apiClient: dependencies.apiClient,
                surfReportService: dependencies.surfReportService,
                weatherBuoyService: dependencies.weatherBuoyService,
                buoyCacheService: dependencies.buoyCacheService
            )
        )
    }
    
    var body: some View {
        NavigationStack {
            MainLayout {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Current conditions card
                    if viewModel.isLoadingConditions {
                        SkeletonCurrentConditions()
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else if let condition = viewModel.currentCondition {
                        currentConditionView(condition)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    RecentReportsSection(
                        reports: viewModel.recentReports,
                        isLoading: viewModel.isLoadingReports,
                        onSelect: { report in
                            selectedReport = report
                        }
                    )
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingReports)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.recentReports.count)
                    
                    WeatherBuoysSection(
                        weatherBuoys: viewModel.weatherBuoys,
                        isLoading: viewModel.isLoadingBuoys
                    )
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingBuoys)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.weatherBuoys.count)
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.refreshData()
                }
                .onAppear {
                    viewModel.loadData()
                }
                .safeAreaInset(edge: .bottom) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 0)
                }
                .navigationTitle("Treble Surf")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ThemeToggleButton()
                    }
                }
                .sheet(item: $selectedReport) { report in
                    SurfReportDetailView(report: report, apiClient: apiClient)
                }
                .sheet(isPresented: $showingVideoPlayer) {
                    if let videoURL = videoURL {
                        let player = AVPlayer(url: videoURL)
                        VideoPlayer(player: player)
                            .ignoresSafeArea()
                            .onAppear {
                                // Auto-play the video when the player appears
                                player.play()
                            }
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        )
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        )
        .padding(.horizontal)
    }
    
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(dependencies: AppDependencies())
    }
}


