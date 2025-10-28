//
//  EnhancedForecastView.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 01/01/2025.
//

import SwiftUI

struct EnhancedForecastView: View {
    @StateObject private var forecastViewModel: SpotForecastViewModel
    @StateObject private var swellPredictionService = SwellPredictionService.shared
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var dataStore: DataStore
    
    var spot: SpotData
    var spotImage: Image? = nil
    var onForecastSelectionChanged: ((ForecastEntry?) -> Void)? = nil
    var onSwellPredictionSelectionChanged: ((SwellPredictionEntry?) -> Void)? = nil
    
    @State private var selectedCardIndex: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isUserScrolling: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isLoadingSwellPredictions: Bool = false
    @State private var swellPredictionError: Error?
    @State private var swellPredictions: [SwellPredictionEntry] = []
    
    init(spot: SpotData, spotImage: Image? = nil, onForecastSelectionChanged: ((ForecastEntry?) -> Void)? = nil, onSwellPredictionSelectionChanged: ((SwellPredictionEntry?) -> Void)? = nil) {
        self.spot = spot
        self.spotImage = spotImage
        self.onForecastSelectionChanged = onForecastSelectionChanged
        self.onSwellPredictionSelectionChanged = onSwellPredictionSelectionChanged
        
        let dataStore = DataStore.shared
        let viewModel = SpotForecastViewModel(dataStore: dataStore)
        self._forecastViewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced mode selector with swell predictions toggle
            enhancedModeSelector
            
            // Compact date/time header
            compactDateTimeHeader
            
            // Forecast cards (traditional or swell predictions)
            forecastScrollView
            
            // Detailed forecast section
            detailedForecastSection
        }
        .onAppear {
            loadForecastData()
            if settingsStore.showSwellPredictions {
                loadSwellPredictionData()
            }
        }
        .onChange(of: settingsStore.showSwellPredictions) { _, showPredictions in
            if showPredictions {
                loadSwellPredictionData()
            } else {
                swellPredictionService.clearCache(for: spot.id)
            }
        }
        .onChange(of: forecastViewModel.filteredEntries) { _, entries in
            handleEntriesChange(entries)
        }
    }
    
    // MARK: - Enhanced UI Components
    
    @ViewBuilder
    private var enhancedModeSelector: some View {
        VStack(spacing: 12) {
            // Traditional mode selector
            HStack(spacing: 0) {
                ForEach(ForecastViewMode.allCases) { mode in
                    let isSelected = forecastViewModel.selectedMode == mode
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            forecastViewModel.setViewMode(mode)
                        }
                    }) {
                        Text(mode.rawValue)
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? Color.blue : Color.clear)
                            )
                            .scaleEffect(isSelected ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
            )
            
            // Swell prediction toggle
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("AI Swell Predictions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Toggle("", isOn: $settingsStore.showSwellPredictions)
                    .labelsHidden()
                    .tint(.purple)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var compactDateTimeHeader: some View {
        if settingsStore.showSwellPredictions {
            swellPredictionHeader
        } else {
            traditionalForecastHeader
        }
    }
    
    @ViewBuilder
    private var traditionalForecastHeader: some View {
        if let selectedEntry = forecastViewModel.filteredEntries.indices.contains(selectedCardIndex) ? forecastViewModel.filteredEntries[selectedCardIndex] : nil {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(Self.compactDayFormatter.string(from: selectedEntry.dateForecastedFor))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if isCurrentDay(selectedEntry.dateForecastedFor) {
                            Text("TODAY")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(Self.timeFormatter.string(from: selectedEntry.dateForecastedFor))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(qualityColor(for: selectedEntry.directionQuality))
                    Text("\(Int(selectedEntry.directionQuality * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray6))
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var swellPredictionHeader: some View {
        if let selectedPrediction = swellPredictions.indices.contains(selectedCardIndex) ? swellPredictions[selectedCardIndex] : swellPredictions.first {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(Self.compactDayFormatter.string(from: selectedPrediction.arrivalTime))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("AI")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .cornerRadius(4)
                        
                        if swellPredictions.count > 1 {
                            Text("\(selectedCardIndex + 1)/\(swellPredictions.count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("Arrives: \(Self.timeFormatter.string(from: selectedPrediction.arrivalTime))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(confidenceColor(for: selectedPrediction.confidence))
                    Text(selectedPrediction.confidencePercentage)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray6))
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        } else if isLoadingSwellPredictions {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading AI predictions...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        } else if swellPredictionError != nil {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("AI predictions unavailable")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var forecastScrollView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    ScrollOffsetReader(coordinateSpace: "forecastScroll") { offset in
                        handleScrollOffsetChange(offset)
                    }
                    
                    HStack(spacing: 0) {
                        if settingsStore.showSwellPredictions {
                            swellPredictionCards(scrollProxy: scrollProxy)
                        } else {
                            traditionalForecastCards(scrollProxy: scrollProxy)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 150)// Ensure minimum height for cards
                }
            }
            .coordinateSpace(name: "forecastScroll")
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in
                        isUserScrolling = true
                    }
                    .onEnded { _ in
                        let finalIndex = calculateMostVisibleCard(from: scrollOffset)
                        
                        DispatchQueue.main.async {
                            if finalIndex != self.selectedCardIndex {
                                self.selectedCardIndex = finalIndex
                                self.handleSelectionChange(finalIndex)
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                self.isUserScrolling = false
                            }
                        }
                    }
            )
            .onAppear {
                selectFirstCard()
            }
        }
    }
    
    @ViewBuilder
    private func traditionalForecastCards(scrollProxy: ScrollViewProxy) -> some View {
        ForEach(Array(forecastViewModel.filteredEntries.enumerated()), id: \.element.id) { index, entry in
            HStack(spacing: 0) {
                ForecastCard(
                    entry: entry,
                    isSelected: index == selectedCardIndex,
                    onTap: {
                        selectCard(at: index, scrollAction: { index in
                            scrollProxy.scrollTo(index, anchor: UnitPoint.center)
                        })
                    }
                )
                .id(index)
                
                if index < forecastViewModel.filteredEntries.count - 1 {
                    Spacer()
                        .frame(width: spacingAfterCard(at: index))
                }
            }
        }
    }
    
    @ViewBuilder
    private func swellPredictionCards(scrollProxy: ScrollViewProxy) -> some View {
        if !swellPredictions.isEmpty {
            ForEach(Array(swellPredictions.enumerated()), id: \.element.id) { index, prediction in
                HStack(spacing: 0) {
                    SwellPredictionCard(
                        prediction: prediction,
                        isSelected: index == selectedCardIndex,
                        onTap: {
                            selectCard(at: index, scrollAction: { index in
                                scrollProxy.scrollTo(index, anchor: UnitPoint.center)
                            })
                        }
                    )
                    .id(index)
                    
                    if index < swellPredictions.count - 1 {
                        Spacer()
                            .frame(width: 8)
                    }
                }
            }
        } else {
            // Placeholder card when no prediction available
            VStack(spacing: 6) {
                Text("No AI")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("Prediction")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(6)
            .frame(width: 70)
            .frame(minHeight: 100)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            )
            .id(0)
        }
    }
    
    @ViewBuilder
    private var detailedForecastSection: some View {
        if settingsStore.showSwellPredictions {
            swellPredictionDetailSection
        } else {
            traditionalForecastDetailSection
        }
    }
    
    @ViewBuilder
    private var traditionalForecastDetailSection: some View {
        if let selectedEntry = forecastViewModel.filteredEntries.indices.contains(selectedCardIndex) ? forecastViewModel.filteredEntries[selectedCardIndex] : nil {
            VStack(spacing: 16) {
                HStack {
                    Text("Forecast Details")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(Self.timeFormatter.string(from: selectedEntry.dateForecastedFor))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray6))
                        )
                }
                .padding(.horizontal, 16)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ReadingCard(
                        title: "Swell Height",
                        value: String(format: "%.1f", selectedEntry.swellHeight),
                        unit: "m",
                        icon: "water.waves"
                    )
                    
                    ReadingCard(
                        title: "Swell Period",
                        value: String(format: "%.0f", selectedEntry.swellPeriod),
                        unit: "sec",
                        icon: "timer"
                    )
                    
                    ReadingCard(
                        title: "Swell Direction",
                        value: String(format: "%.0f", selectedEntry.swellDirection),
                        unit: "°",
                        icon: "location.north"
                    )
                    
                    ReadingCard(
                        title: "Direction Quality",
                        value: String(format: "%.0f", selectedEntry.directionQuality * 100),
                        unit: "%",
                        icon: "star.fill"
                    )
                    
                    ReadingCard(
                        title: "Wind Speed",
                        value: String(format: "%.1f", selectedEntry.windSpeed * 3.6),
                        unit: "km/h",
                        icon: "wind"
                    )
                    
                    ReadingCard(
                        title: "Wind Direction",
                        value: String(format: "%.0f", selectedEntry.windDirection),
                        unit: "°",
                        icon: "arrow.up.right"
                    )
                    
                    ReadingCard(
                        title: "Temperature",
                        value: String(format: "%.0f", selectedEntry.temperature),
                        unit: "°C",
                        icon: "thermometer"
                    )
                    
                    ReadingCard(
                        title: "Wave Energy",
                        value: String(format: "%.0f", selectedEntry.waveEnergy),
                        unit: "kJ/m²",
                        icon: "bolt"
                    )
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
            .padding(.bottom, 16)
        }
    }
    
    @ViewBuilder
    private var swellPredictionDetailSection: some View {
        if let selectedPrediction = swellPredictions.indices.contains(selectedCardIndex) ? swellPredictions[selectedCardIndex] : swellPredictions.first {
            SwellPredictionDetailCard(prediction: selectedPrediction)
                .padding(.vertical, 16)
                .padding(.bottom, 16)
        } else {
            VStack(spacing: 16) {
                HStack {
                    Text("AI Swell Prediction")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.largeTitle)
                        .foregroundColor(.purple)
                    
                    Text("No AI prediction available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let error = swellPredictionError {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 32)
            }
            .padding(.vertical, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Helper Methods
    
    private static let compactDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df
    }()
    
    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        df.timeZone = TimeZone(abbreviation: "UTC")
        return df
    }()
    
    private func isCurrentDay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    private func qualityColor(for quality: Double) -> Color {
        if quality >= 0.8 { return .green }
        else if quality >= 0.6 { return .yellow }
        else if quality >= 0.4 { return .orange }
        else { return .red }
    }
    
    private func confidenceColor(for confidence: Double) -> Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .yellow }
        else if confidence >= 0.4 { return .orange }
        else { return .red }
    }
    
    private func loadForecastData() {
        forecastViewModel.fetchForecast(for: spot.id) { success in
            if !success {
                print("Failed to fetch forecast for spot: \(spot.id)")
            }
        }
    }
    
    private func loadSwellPredictionData() {
        
        isLoadingSwellPredictions = true
        swellPredictionError = nil
        
        swellPredictionService.fetchSwellPrediction(for: spot) { result in
            DispatchQueue.main.async {
                self.isLoadingSwellPredictions = false
                
                switch result {
                case .success(let predictions):
                    self.swellPredictions = predictions
                    // Notify with the first prediction for backward compatibility
                    self.onSwellPredictionSelectionChanged?(predictions.first)
                case .failure(let error):
                    self.swellPredictionError = error
                    self.swellPredictions = []
                    self.onSwellPredictionSelectionChanged?(nil)
                }
            }
        }
    }
    
    private func handleEntriesChange(_ entries: [ForecastEntry]) {
        if let firstEntry = entries.first, selectedCardIndex == 0 {
            onForecastSelectionChanged?(firstEntry)
        }
    }
    
    private func selectFirstCard() {
        if settingsStore.showSwellPredictions {
            selectedCardIndex = 0
            if !swellPredictions.isEmpty {
                onSwellPredictionSelectionChanged?(swellPredictions[0])
            }
        } else if !forecastViewModel.filteredEntries.isEmpty {
            selectedCardIndex = 0
            onForecastSelectionChanged?(forecastViewModel.filteredEntries[0])
        }
    }
    
    private func selectCard(at index: Int, scrollAction: @escaping (Int) -> Void) {
        isUserScrolling = false
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedCardIndex = index
            handleSelectionChange(index)
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            scrollAction(index)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isUserScrolling = false
        }
    }
    
    private func handleSelectionChange(_ newIndex: Int) {
        if settingsStore.showSwellPredictions {
            if newIndex < swellPredictions.count {
                onSwellPredictionSelectionChanged?(swellPredictions[newIndex])
            }
        } else if newIndex < forecastViewModel.filteredEntries.count {
            onForecastSelectionChanged?(forecastViewModel.filteredEntries[newIndex])
        }
    }
    
    private func spacingAfterCard(at index: Int) -> CGFloat {
        guard index < forecastViewModel.filteredEntries.count - 1 else { return 0 }
        
        let currentEntry = forecastViewModel.filteredEntries[index]
        let nextEntry = forecastViewModel.filteredEntries[index + 1]
        
        let calendar = Calendar.current
        let currentDay = calendar.dateComponents([.year, .month, .day], from: currentEntry.dateForecastedFor)
        let nextDay = calendar.dateComponents([.year, .month, .day], from: nextEntry.dateForecastedFor)
        
        return (currentDay != nextDay) ? 24 : 8
    }
    
    private func calculateMostVisibleCard(from scrollOffset: CGFloat) -> Int {
        // Use a very simple approach: calculate based on scroll offset and average card width
        // This is more reliable than trying to track exact positions
        
        let screenWidth = UIScreen.main.bounds.width
        let scrollViewPadding: CGFloat = 16
        
        // Calculate which card should be centered based on scroll offset
        // Each card is approximately 70 points wide + 8 points average spacing = 78 points total
        let averageCardWidth: CGFloat = 78
        
        // Calculate the scroll position relative to the start of the content
        let scrollPosition = abs(scrollOffset) + (screenWidth / 2) - scrollViewPadding
        
        // Determine which card index this position corresponds to
        let cardIndex = Int(scrollPosition / averageCardWidth)
        
        // Clamp to valid range based on current mode
        if settingsStore.showSwellPredictions {
            return max(0, min(cardIndex, swellPredictions.count - 1))
        } else {
            return max(0, min(cardIndex, forecastViewModel.filteredEntries.count - 1))
        }
    }
    
    private func handleScrollOffsetChange(_ offset: CGFloat) {
        scrollOffset = offset
        
        guard isUserScrolling else { return }
        
        let offsetDifference = abs(offset - lastScrollOffset)
        guard offsetDifference >= 2 else { return }
        
        lastScrollOffset = offset
        
        let newIndex = calculateMostVisibleCard(from: offset)
        
        if newIndex != selectedCardIndex {
            DispatchQueue.main.async {
                self.selectedCardIndex = newIndex
                self.handleSelectionChange(newIndex)
            }
        }
    }
}
