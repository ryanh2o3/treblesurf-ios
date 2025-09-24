//
//  SwellPredictionTestView.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 01/01/2025.
//

import SwiftUI

struct SwellPredictionTestView: View {
    @StateObject private var swellPredictionService = SwellPredictionService.shared
    @EnvironmentObject var settingsStore: SettingsStore
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Settings toggle
                HStack {
                    Text("Show Swell Predictions")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $settingsStore.showSwellPredictions)
                        .labelsHidden()
                }
                .padding()
                
                // Test API call
                Button("Test Swell Prediction API") {
                    testSwellPredictionAPI()
                }
                .buttonStyle(.borderedProminent)
                
                // Status display
                if swellPredictionService.isLoading {
                    ProgressView("Loading swell predictions...")
                }
                
                if let error = swellPredictionService.lastError {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Display cached predictions
                if !swellPredictionService.predictions.isEmpty {
                    List {
                        ForEach(Array(swellPredictionService.predictions.values), id: \.id) { prediction in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Spot: \(prediction.spotId)")
                                    .font(.headline)
                                
                                HStack {
                                    Text("Surf Size: \(String(format: "%.1f", prediction.surfSize))m")
                                    Spacer()
                                    Text("Confidence: \(prediction.confidencePercentage)")
                                        .foregroundColor(confidenceColor(for: prediction.confidence))
                                }
                                
                                HStack {
                                    Text("Arrival: \(prediction.formattedArrivalTime)")
                                    Spacer()
                                    Text("Travel: \(prediction.formattedTravelTime)")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Text("No swell predictions cached")
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Swell Prediction Test")
        }
    }
    
    private func testSwellPredictionAPI() {
        // Test with a sample spot
        let testSpot = SpotData(
            beachDirection: 270,
            idealSwellDirection: "W",
            latitude: 55.186844,
            longitude: -7.59785,
            type: "Beach",
            countryRegionSpot: "Ireland/Donegal/Bundoran",
            image: "",
            imageString: nil
        )
        
        swellPredictionService.fetchSwellPrediction(for: testSpot) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let predictions):
                    print("✅ Swell predictions fetched successfully: \(predictions.count) predictions")
                    for (index, prediction) in predictions.enumerated() {
                        let timeFormatter = DateFormatter()
                        timeFormatter.dateFormat = "HH:mm"
                        timeFormatter.timeZone = TimeZone(abbreviation: "UTC")
                        let timeString = timeFormatter.string(from: prediction.arrivalTime)
                        print("  Prediction \(index + 1): \(prediction.surfSize)m surf size, arrives at \(prediction.formattedArrivalTime) (\(timeString) UTC)")
                    }
                case .failure(let error):
                    print("❌ Failed to fetch swell predictions: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func confidenceColor(for confidence: Double) -> Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .yellow }
        else if confidence >= 0.4 { return .orange }
        else { return .red }
    }
}

#Preview {
    SwellPredictionTestView()
        .environmentObject(SettingsStore.shared)
}
