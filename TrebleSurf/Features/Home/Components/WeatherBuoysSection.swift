import SwiftUI

struct WeatherBuoysSection: View {
    let weatherBuoys: [WeatherBuoy]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weather Buoys")
                .font(.headline)
                .padding(.horizontal)
            
            if isLoading {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(0..<2, id: \.self) { _ in
                        SkeletonBuoyCard()
                    }
                }
                .padding(.horizontal)
                .transition(.opacity)
            } else if weatherBuoys.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "water.waves.slash")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No buoy data available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 120)
                    Spacer()
                }
                .padding(.horizontal)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(weatherBuoys) { buoy in
                        weatherBuoyCard(buoy)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.horizontal)
                .transition(.opacity)
            }
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        )
    }
}
