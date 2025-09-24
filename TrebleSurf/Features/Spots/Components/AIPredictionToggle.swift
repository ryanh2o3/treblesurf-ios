//
//  AIPredictionToggle.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 01/01/2025.
//

import SwiftUI

struct AIPredictionToggle: View {
    @Binding var isEnabled: Bool
    @State private var aiPrediction: SwellPredictionEntry? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    let spotId: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toggle header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("AI Prediction")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .onChange(of: isEnabled) { _, newValue in
                        if newValue {
                            fetchAIPrediction()
                        }
                    }
            }
            
            // AI Prediction content
            if isEnabled {
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading AI prediction...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                } else if let prediction = aiPrediction {
                    AIPredictionCard(prediction: prediction)
                } else if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        Text("No AI prediction available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func fetchAIPrediction() {
        // Convert spotId back to country/region/spot format
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            errorMessage = "Invalid spot ID format"
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        isLoading = true
        errorMessage = nil
        
        APIClient.shared.fetchClosestAIPrediction(country: country, region: region, spot: spot) { [self] result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.aiPrediction = SwellPredictionEntry(from: response)
                case .failure(let error):
                    self.errorMessage = "Failed to load AI prediction: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct AIPredictionCard: View {
    let prediction: SwellPredictionEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with confidence and quality
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Predicted Surf Size")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(String(format: "%.1f ft", prediction.surfSize))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: prediction.qualityAssessment.icon)
                            .foregroundColor(Color(prediction.qualityAssessment.color))
                        Text(prediction.qualityAssessment.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color(prediction.qualityAssessment.color))
                    }
                    
                    Text(prediction.confidencePercentage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Prediction details grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                PredictionDetailCard(
                    title: "Height",
                    value: String(format: "%.1f", prediction.predictedHeight),
                    unit: "m",
                    icon: "water.waves"
                )
                
                PredictionDetailCard(
                    title: "Period",
                    value: String(format: "%.0f", prediction.predictedPeriod),
                    unit: "sec",
                    icon: "timer"
                )
                
                PredictionDetailCard(
                    title: "Direction",
                    value: String(format: "%.0f°", prediction.predictedDirection),
                    unit: "",
                    icon: "arrow.up.right"
                )
                
                PredictionDetailCard(
                    title: "Travel Time",
                    value: prediction.formattedTravelTime,
                    unit: "",
                    icon: "clock"
                )
            }
            
            // Additional info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Arrival Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(prediction.formattedArrivalTime)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Direction Quality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(prediction.directionQualityPercentage)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
}

struct PredictionDetailCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.5))
        .cornerRadius(8)
    }
}

#Preview {
    VStack {
        AIPredictionToggle(isEnabled: .constant(true), spotId: "Ireland#Donegal#Bundoran")
            .padding()
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}
