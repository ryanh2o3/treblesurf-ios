//
//  EnhancedSpotOverlay.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 01/01/2025.
//

import SwiftUI

struct EnhancedSpotOverlay: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var swellPredictionService: SwellPredictionService
    
    let spotId: String
    let selectedForecastEntry: ForecastEntry?
    let selectedSwellPrediction: SwellPredictionEntry?
    
    var body: some View {
        ZStack {
            // Direction arrows - centered
            HStack(spacing: 8) {
                if settingsStore.showSwellPredictions, let swellPrediction = selectedSwellPrediction {
                    // AI Swell arrow (purple)
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.purple)
                            .rotationEffect(Angle(degrees: swellPrediction.predictedDirection))
                            .animation(.easeInOut(duration: 0.4), value: swellPrediction.id)
                            .scaleEffect(1.0)
                    }
                } else {
                    // Traditional Swell arrow (blue)
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.blue)
                            .rotationEffect(Angle(degrees: selectedForecastEntry?.swellDirection ?? dataStore.currentConditions.swellDirection))
                            .animation(.easeInOut(duration: 0.4), value: selectedForecastEntry?.id)
                            .scaleEffect(1.0)
                    }
                }
                
                // Wind arrow (white) - always show traditional wind data
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(Angle(degrees: selectedForecastEntry?.windDirection ?? dataStore.currentConditions.windDirection))
                        .animation(.easeInOut(duration: 0.4), value: selectedForecastEntry?.id)
                        .scaleEffect(1.0)
                }
            }
            
            // Legends in top right
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(settingsStore.showSwellPredictions && selectedSwellPrediction != nil ? Color.purple : Color.blue)
                        .frame(width: 12, height: 12)
                    Text(settingsStore.showSwellPredictions && selectedSwellPrediction != nil ? "AI Swell" : "Swell")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                    Text("Wind")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(maxHeight: .infinity, alignment: .top)
            
            // AI prediction indicator in bottom left
            if settingsStore.showSwellPredictions, let swellPrediction = selectedSwellPrediction {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Text("AI Prediction")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(confidenceColor(for: swellPrediction.confidence))
                        Text(swellPrediction.confidencePercentage)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .cornerRadius(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .onAppear {
            // Fetch current conditions when overlay appears
            Task { _ = await dataStore.fetchConditions(for: spotId) }
        }
    }
    
    private func confidenceColor(for confidence: Double) -> Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .yellow }
        else if confidence >= 0.4 { return .orange }
        else { return .red }
    }
}

