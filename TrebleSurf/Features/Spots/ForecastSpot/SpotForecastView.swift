
// SpotForecastView.swift
import SwiftUI
import Charts

// MARK: - Scroll Position Tracking
struct ScrollPositionPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetReader: View {
    let coordinateSpace: String
    let onOffsetChange: (CGFloat) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: ScrollPositionPreferenceKey.self,
                           value: geometry.frame(in: .named(coordinateSpace)).minX)
                .onPreferenceChange(ScrollPositionPreferenceKey.self) { value in
                    onOffsetChange(value)
                }
        }
        .frame(height: 0)
    }
}





struct SpotForecastView: View {
    @StateObject private var viewModel: SpotForecastViewModel
    @EnvironmentObject var dataStore: DataStore
    var spotId: String
    var spotImage: Image? = nil
    var onForecastSelectionChanged: ((ForecastEntry) -> Void)? = nil
    @State private var currentForecastEntry: ForecastEntry? = nil
    @State private var selectedCardIndex: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isUserScrolling: Bool = false
    @State private var lastSelectionTime: Date = Date()

        
    init(spotId: String, spotImage: Image? = nil, onForecastSelectionChanged: ((ForecastEntry) -> Void)? = nil) {
        self.spotId = spotId
        self.spotImage = spotImage
        self.onForecastSelectionChanged = onForecastSelectionChanged
        
        let dataStore = DataStore.shared
        let viewModel = SpotForecastViewModel(dataStore: dataStore)
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            modeToggleButtons
            selectedTimeIndicator
            forecastScrollView
            detailedForecastSection
        }
        .onAppear {
            loadForecastData()
        }
        .onChange(of: viewModel.filteredEntries) { entries in
            handleEntriesChange(entries)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var modeToggleButtons: some View {
        HStack {
            ForEach(ForecastViewMode.allCases) { mode in
                let isSelected = viewModel.selectedMode == mode
                let backgroundColor = isSelected ? Color.blue : Color(.systemGray5)
                let textColor = isSelected ? Color.white : Color.primary
                
                Button(action: {
                    viewModel.setViewMode(mode)
                }) {
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(backgroundColor)
                        )
                        .foregroundColor(textColor)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 6)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var selectedTimeIndicator: some View {
        if let selectedEntry = currentForecastEntry {
            VStack(spacing: 8) {
                // Dynamic day header that updates with selection
                HStack {
                    Text(dayHeaderFormatter.string(from: selectedEntry.dateForecastedFor))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if isCurrentDay(selectedEntry.dateForecastedFor) {
                        Text("TODAY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                
                // Time indicator
                HStack {
                    Text("Time: \(timeFormatter.string(from: selectedEntry.dateForecastedFor))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 6)
            .padding(.bottom, 16)
        }
    }
    
    @ViewBuilder
    private var forecastScrollView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Scroll offset reader
                    ScrollOffsetReader(coordinateSpace: "forecastScroll") { offset in
                        handleScrollOffsetChange(offset)
                    }
                    
                    HStack(spacing: 0) {
                        ForEach(Array(viewModel.filteredEntries.enumerated()), id: \.element.id) { index, entry in
                            HStack(spacing: 0) {
                                ForecastCard(
                                    entry: entry,
                                    isSelected: index == selectedCardIndex,
                                    onTap: {
                                        selectCard(at: index, entry: entry, scrollAction: { index in
                                            scrollProxy.scrollTo(index, anchor: .center)
                                        })
                                    }
                                )
                                .id(index)
                                
                                // Add spacing after each card, with larger spacing between days
                                if index < viewModel.filteredEntries.count - 1 {
                                    Spacer()
                                        .frame(width: spacingAfterCard(at: index))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .coordinateSpace(name: "forecastScroll")
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in
                        isUserScrolling = true
                    }
                    .onEnded { _ in
                        // Delay to allow final scroll position to settle
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isUserScrolling = false
                        }
                    }
            )
            .onAppear {
                selectFirstCard()
            }
            .onChange(of: selectedCardIndex) { newIndex in
                // Only handle manual selection changes, not auto-selection changes
                if !isUserScrolling {
                    handleSelectionChange(newIndex)
                }
            }
        }
    }
    

    
    @ViewBuilder
    private var detailedForecastSection: some View {
        if let selectedEntry = currentForecastEntry {
            VStack(spacing: 20) {
                Text("Detailed Forecast for \(timeFormatter.string(from: selectedEntry.dateForecastedFor))")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                
                // Surf conditions grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
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
            .padding(.vertical, 20)
            .background(Color(.systemGray6).opacity(0.3))
            .cornerRadius(16)
            .padding(.horizontal, 6)
            .padding(.bottom, 20)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut(duration: 0.3), value: selectedEntry)
        }
    }
    
    // MARK: - Helper Methods
    
    private var groupedForecasts: [Date: [ForecastEntry]] {
        let calendar = Calendar.current
        let entries = viewModel.filteredEntries
        
        return Dictionary(grouping: entries) { entry in
            let components = calendar.dateComponents([.year, .month, .day], from: entry.dateForecastedFor)
            return calendar.date(from: components) ?? entry.dateForecastedFor
        }
    }
    
    private var dayHeaderFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }
    
    private func isCurrentDay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    private func loadForecastData() {
        viewModel.fetchForecast(for: spotId) { success in
            if !success {
                print("Failed to fetch forecast for spot: \(spotId)")
            }
        }
    }
    
    private func handleEntriesChange(_ entries: [ForecastEntry]) {
        if let firstEntry = entries.first, currentForecastEntry == nil {
            currentForecastEntry = firstEntry
        }
    }
    
    private func selectFirstCard() {
        if !viewModel.filteredEntries.isEmpty {
            selectedCardIndex = 0
            currentForecastEntry = viewModel.filteredEntries[0]
            onForecastSelectionChanged?(viewModel.filteredEntries[0])
        }
    }
    
    private func selectCard(at index: Int, entry: ForecastEntry, scrollAction: @escaping (Int) -> Void) {
        // Disable user scrolling detection during manual selection
        isUserScrolling = false
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedCardIndex = index
            currentForecastEntry = entry
            onForecastSelectionChanged?(entry)
        }
        
        // Scroll to the selected card
        withAnimation(.easeInOut(duration: 0.3)) {
            scrollAction(index)
        }
        
        // Re-enable after the scroll animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isUserScrolling = false
        }
    }
    
    private func handleSelectionChange(_ newIndex: Int) {
        if newIndex < viewModel.filteredEntries.count {
            currentForecastEntry = viewModel.filteredEntries[newIndex]
            onForecastSelectionChanged?(viewModel.filteredEntries[newIndex])
        }
    }
    
    // MARK: - Layout Helpers
    
    private func spacingAfterCard(at index: Int) -> CGFloat {
        guard index < viewModel.filteredEntries.count - 1 else { return 0 }
        
        let currentEntry = viewModel.filteredEntries[index]
        let nextEntry = viewModel.filteredEntries[index + 1]
        
        let calendar = Calendar.current
        let currentDay = calendar.dateComponents([.year, .month, .day], from: currentEntry.dateForecastedFor)
        let nextDay = calendar.dateComponents([.year, .month, .day], from: nextEntry.dateForecastedFor)
        
        // If it's a different day, use larger spacing
        if currentDay != nextDay {
            return 24  // Larger gap between days
        } else {
            return 8   // Smaller gap within the same day
        }
    }
    
    // MARK: - Auto-Selection Logic
    
    private func calculateMostVisibleCard(from scrollOffset: CGFloat) -> Int {
        let cardWidth: CGFloat = 80 // Updated card width
        let cardPadding: CGFloat = 8 // Updated internal padding
        let totalCardWidth = cardWidth + (cardPadding * 2) // Width including padding
        let screenWidth = UIScreen.main.bounds.width
        let scrollViewPadding: CGFloat = 16
        
        // Calculate the center of the visible screen area
        let screenCenter = screenWidth / 2
        
        // The scroll offset is negative when scrolling right
        // Calculate positions of each card to find the most centered one
        var bestIndex = 0
        var minDistanceToCenter = CGFloat.infinity
        
        var currentX: CGFloat = scrollViewPadding + cardPadding + (cardWidth / 2)
        
        for index in 0..<viewModel.filteredEntries.count {
            // Calculate this card's center position relative to the scroll content
            let cardCenterX = currentX
            
            // Calculate where this card appears on screen given the current scroll offset
            let cardScreenX = cardCenterX + scrollOffset
            
            // Calculate distance from screen center - bias towards selecting earlier
            let distanceFromCenter = abs(cardScreenX - screenCenter)
            let biasedDistance = distanceFromCenter - 20 // Bias to select 20px earlier
            
            if biasedDistance < minDistanceToCenter {
                minDistanceToCenter = biasedDistance
                bestIndex = index
            }
            
            // Move to next card position
            currentX += totalCardWidth + spacingAfterCard(at: index)
        }
        
        return bestIndex
    }
    
    private func handleScrollOffsetChange(_ offset: CGFloat) {
        scrollOffset = offset
        
        // Only auto-select if user is actively scrolling (not when programmatically scrolling)
        if isUserScrolling {
            let newIndex = calculateMostVisibleCard(from: offset)
            
            // Only update if the calculated index is different and enough time has passed
            if newIndex != selectedCardIndex {
                let now = Date()
                let timeSinceLastSelection = now.timeIntervalSince(lastSelectionTime)
                
                // Debounce rapid selections (minimum 50ms between selections)
                if timeSinceLastSelection >= 0.05 {
                    lastSelectionTime = now
                    
                    // Update without animation for smoother scrolling
                    selectedCardIndex = newIndex
                    if newIndex < viewModel.filteredEntries.count {
                        currentForecastEntry = viewModel.filteredEntries[newIndex]
                        onForecastSelectionChanged?(viewModel.filteredEntries[newIndex])
                    }
                }
            }
        }
    }
}

// Forecast card component
struct ForecastCard: View {
    let entry: ForecastEntry
    let isSelected: Bool
    let onTap: () -> Void
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Time header
            Text(timeFormatter.string(from: entry.dateForecastedFor))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            // Swell height (main metric)
            VStack(spacing: 4) {
                Text("\(entry.swellHeight, specifier: "%.1f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("m")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Swell period
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(Int(entry.swellPeriod))s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Wind info
            HStack(spacing: 4) {
                Image(systemName: "wind")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(Int(entry.windSpeed * 3.6)) km/h")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Temperature
            HStack(spacing: 4) {
                Image(systemName: "thermometer")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(Int(entry.temperature))°C")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Quality indicator
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(qualityColor)
                Text("\(Int(entry.directionQuality * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 80, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .padding(8)
        .onTapGesture {
            onTap()
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .shadow(color: isSelected ? Color.blue.opacity(0.2) : Color.black.opacity(0.05), radius: isSelected ? 4 : 2, x: 0, y: 1)
    }
    
    private var qualityColor: Color {
        let quality = entry.directionQuality
        if quality >= 0.8 { return .green }
        else if quality >= 0.6 { return .yellow }
        else if quality >= 0.4 { return .orange }
        else { return .red }
    }
}






