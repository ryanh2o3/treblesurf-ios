//
//  AIPredictedForecastCard.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 01/01/2025.
//

import SwiftUI

struct AIPredictedForecastCard: View {
    let prediction: AIPredictedForecastEntry
    let isSelected: Bool
    let onTap: () -> Void
    
    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()
    
    var body: some View {
        VStack(spacing: 6) {
            // Time header with AI indicator
            HStack(spacing: 4) {
                Text(Self.timeFormatter.string(from: prediction.arrivalTime))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                // AI prediction indicator
                Image(systemName: "brain.head.profile")
                    .font(.caption2)
                    .foregroundColor(.purple)
            }
            
            // Surf size (main metric) - more prominent
            VStack(spacing: 2) {
                Text("\(prediction.surfSize, specifier: "%.1f")")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("m")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Compact metrics row
            VStack(spacing: 3) {
                // Confidence indicator
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(confidenceColor)
                    Text("\(Int(prediction.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Hours ahead
                HStack(spacing: 3) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(prediction.formattedHoursAhead)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Quality indicator with color
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(qualityColor)
                    Text("\(Int(prediction.directionQuality * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 70, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.purple.opacity(0.15) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 1.5)
                )
        )
        .padding(6)
        .onTapGesture {
            onTap()
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .shadow(color: isSelected ? Color.purple.opacity(0.25) : Color.black.opacity(0.08), radius: isSelected ? 3 : 1, x: 0, y: 1)
    }
    
    private var confidenceColor: Color {
        let confidence = prediction.confidence
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .yellow }
        else if confidence >= 0.4 { return .orange }
        else { return .red }
    }
    
    private var qualityColor: Color {
        let quality = prediction.directionQuality
        if quality >= 0.8 { return .green }
        else if quality >= 0.6 { return .yellow }
        else if quality >= 0.4 { return .orange }
        else { return .red }
    }
}

struct AIPredictedForecastDetailCard: View {
    let prediction: AIPredictedForecastEntry
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with AI indicator
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("AI Predicted Forecast")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Confidence badge
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(confidenceColor)
                    Text(prediction.confidencePercentage)
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
            
            // Main prediction metrics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ReadingCard(
                    title: "Predicted Height",
                    value: String(format: "%.1f", prediction.predictedHeight),
                    unit: "m",
                    icon: "water.waves"
                )
                
                ReadingCard(
                    title: "Surf Size",
                    value: String(format: "%.1f", prediction.surfSize),
                    unit: "m",
                    icon: "wave.3.right"
                )
                
                ReadingCard(
                    title: "Predicted Period",
                    value: String(format: "%.0f", prediction.predictedPeriod),
                    unit: "sec",
                    icon: "timer"
                )
                
                ReadingCard(
                    title: "Predicted Direction",
                    value: String(format: "%.0f", prediction.predictedDirection),
                    unit: "°",
                    icon: "location.north"
                )
                
                ReadingCard(
                    title: "Travel Time",
                    value: prediction.formattedTravelTime,
                    unit: "",
                    icon: "clock.arrow.circlepath"
                )
                
                ReadingCard(
                    title: "Distance",
                    value: String(format: "%.1f", prediction.distanceKm),
                    unit: "km",
                    icon: "location"
                )
                
                ReadingCard(
                    title: "Direction Quality",
                    value: prediction.directionQualityPercentage,
                    unit: "",
                    icon: "star.fill"
                )
                
                ReadingCard(
                    title: "Hours Ahead",
                    value: prediction.formattedHoursAhead,
                    unit: "",
                    icon: "clock.arrow.circlepath"
                )
            }
            
            // Calibration info if applied
            if prediction.calibrationApplied {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.blue)
                        Text("Calibration Applied")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calibration Confidence: \(prediction.calibrationConfidencePercentage)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    private var confidenceColor: Color {
        let confidence = prediction.confidence
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .yellow }
        else if confidence >= 0.4 { return .orange }
        else { return .red }
    }
}
