
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
    @State private var lastScrollOffset: CGFloat = 0

        
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
            // Modern segmented control for mode selection
            modernModeSelector
            
            // Compact date/time header
            compactDateTimeHeader
            
            // Forecast cards
            forecastScrollView
            
            // Detailed forecast section
            detailedForecastSection
        }
        .onAppear {
            loadForecastData()
        }
        .onChange(of: viewModel.filteredEntries) { entries in
            handleEntriesChange(entries)
        }
    }
    
    // MARK: - Modern UI Components
    
    @ViewBuilder
    private var modernModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ForecastViewMode.allCases) { mode in
                let isSelected = viewModel.selectedMode == mode
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.setViewMode(mode)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var compactDateTimeHeader: some View {
        if let selectedEntry = currentForecastEntry {
            HStack {
                // Date with compact formatting
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
                
                // Quick quality indicator
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
                        // Process final position immediately, then disable user scrolling
                        let finalIndex = calculateMostVisibleCard(from: scrollOffset)
                        
                        // Use async dispatch to avoid modifying state during view update
                        DispatchQueue.main.async {
                            if finalIndex != self.selectedCardIndex {
                                self.selectedCardIndex = finalIndex
                                if finalIndex < self.viewModel.filteredEntries.count {
                                    self.currentForecastEntry = self.viewModel.filteredEntries[finalIndex]
                                    self.onForecastSelectionChanged?(self.viewModel.filteredEntries[finalIndex])
                                }
                            }
                            
                            // Small delay to prevent conflicts with programmatic scrolling
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                self.isUserScrolling = false
                            }
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
            VStack(spacing: 16) {
                // Compact header with time
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
                
                // Surf conditions grid - more compact
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
    
    // MARK: - Helper Methods
    
    private var groupedForecasts: [Date: [ForecastEntry]] {
        let calendar = Calendar.current
        let entries = viewModel.filteredEntries
        
        return Dictionary(grouping: entries) { entry in
            let components = calendar.dateComponents([.year, .month, .day], from: entry.dateForecastedFor)
            return calendar.date(from: components) ?? entry.dateForecastedFor
        }
    }
    
    private static let dayHeaderFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }()
    
    private static let compactDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df
    }()
    
    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
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
        return (currentDay != nextDay) ? 20 : 4
    }
    
    // MARK: - Auto-Selection Logic
    
    private func calculateMostVisibleCard(from scrollOffset: CGFloat) -> Int {
        let cardWidth: CGFloat = 70 // Updated card width
        let cardPadding: CGFloat = 6 // Updated internal padding
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
            
            // Calculate distance from screen center
            let distanceFromCenter = abs(cardScreenX - screenCenter)
            
            if distanceFromCenter < minDistanceToCenter {
                minDistanceToCenter = distanceFromCenter
                bestIndex = index
            }
            
            // Move to next card position
            currentX += totalCardWidth + spacingAfterCard(at: index)
        }
        
        return bestIndex
    }
    
    private func handleScrollOffsetChange(_ offset: CGFloat) {
        scrollOffset = offset
        
        // Only process if user is scrolling and offset changed meaningfully
        guard isUserScrolling else { return }
        
        // Only calculate if scroll offset changed by at least 2 pixels to reduce excessive calculations
        let offsetDifference = abs(offset - lastScrollOffset)
        guard offsetDifference >= 2 else { return }
        
        lastScrollOffset = offset
        
        let newIndex = calculateMostVisibleCard(from: offset)
        
        // Only update if the calculated index is different
        if newIndex != selectedCardIndex {
            // Use async dispatch to avoid modifying state during view update
            DispatchQueue.main.async {
                // Update without animation for smoother scrolling
                self.selectedCardIndex = newIndex
                if newIndex < self.viewModel.filteredEntries.count {
                    self.currentForecastEntry = self.viewModel.filteredEntries[newIndex]
                    self.onForecastSelectionChanged?(self.viewModel.filteredEntries[newIndex])
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
    
    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()
    
    var body: some View {
        VStack(spacing: 6) {
            // Time header
            Text(Self.timeFormatter.string(from: entry.dateForecastedFor))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            // Swell height (main metric) - more prominent
            VStack(spacing: 2) {
                Text("\(entry.swellHeight, specifier: "%.1f")")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("m")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Compact metrics row
            VStack(spacing: 3) {
                // Swell period
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(entry.swellPeriod))s")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Wind speed
                HStack(spacing: 3) {
                    Image(systemName: "wind")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(entry.windSpeed * 3.6))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Quality indicator with color
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(qualityColor)
                    Text("\(Int(entry.directionQuality * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(6)
        .frame(width: 70)
        .frame(minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                )
        )
        .onTapGesture {
            onTap()
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .shadow(color: isSelected ? Color.blue.opacity(0.25) : Color.black.opacity(0.08), radius: isSelected ? 3 : 1, x: 0, y: 1)
    }
    
    private var qualityColor: Color {
        let quality = entry.directionQuality
        if quality >= 0.8 { return .green }
        else if quality >= 0.6 { return .yellow }
        else if quality >= 0.4 { return .orange }
        else { return .red }
    }
}






