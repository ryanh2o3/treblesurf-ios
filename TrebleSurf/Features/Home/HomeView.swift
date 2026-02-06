import SwiftUI
import AVKit
import Foundation

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var selectedReport: SurfReport?
    @State private var showingVideoPlayer = false
    @State private var videoURL: URL?
    private let surfReportService: SurfReportService
    
    init(dependencies: AppDependencies) {
        self.surfReportService = dependencies.surfReportService
        _viewModel = StateObject(
            wrappedValue: HomeViewModel(
                config: dependencies.config,
                apiClient: dependencies.apiClient,
                spotService: dependencies.spotService,
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
                        CurrentConditionCard(condition: condition)
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
                    SurfReportDetailView(report: report, surfReportService: surfReportService)
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
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(dependencies: AppDependencies())
    }
}


