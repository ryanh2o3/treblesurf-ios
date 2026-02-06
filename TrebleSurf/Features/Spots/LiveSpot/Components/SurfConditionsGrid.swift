// SurfConditionsGrid.swift
import SwiftUI

struct SurfConditionsGrid: View {
    @EnvironmentObject var dataStore: DataStore
    var aiPrediction: SwellPredictionEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Surf Conditions")
                    .font(.headline)

                Spacer()

                // ML indicator
                if aiPrediction != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Text("powered by ML")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // Surf Size - use AI prediction if available
                ReadingCard(
                    title: aiPrediction != nil ? "Surf Size (ML)" : "Surf Size",
                    value: aiPrediction != nil ? String(format: "%.1f", aiPrediction!.surfSize) : String(format: "%.1f", dataStore.currentConditions.surfSize),
                    unit: "m",
                    icon: "water.waves",
                    iconColor: aiPrediction != nil ? .purple : .blue
                )

                // Surf Messiness - keep current conditions
                ReadingCard(
                    title: "Surf Messiness",
                    value: dataStore.currentConditions.surfMessiness,
                    unit: "",
                    icon: "water.waves.and.arrow.up"
                )

                // Relative Wind - keep current conditions
                ReadingCard(
                    title: "Relative Wind",
                    value: dataStore.currentConditions.formattedRelativeWindDirection,
                    unit: "",
                    icon: "arrow.up.left.and.arrow.down.right"
                )

                // Swell Period - use AI prediction if available
                ReadingCard(
                    title: aiPrediction != nil ? "Swell Period (ML)" : "Swell Period",
                    value: aiPrediction != nil ? String(format: "%.0f", aiPrediction!.predictedPeriod) : String(format: "%.0f", dataStore.currentConditions.swellPeriod),
                    unit: "sec",
                    icon: "timer",
                    iconColor: aiPrediction != nil ? .purple : .blue
                )

                // Swell Direction - use AI prediction if available
                ReadingCard(
                    title: aiPrediction != nil ? "Swell Direction (ML)" : "Swell Direction",
                    value: aiPrediction != nil ? String(format: "%.0f", aiPrediction!.predictedDirection) : String(format: "%.0f", dataStore.currentConditions.swellDirection),
                    unit: "\u{00B0}",
                    icon: "swellDirection",
                    iconColor: aiPrediction != nil ? .purple : .blue
                )

                // Wave Energy - keep current conditions
                ReadingCard(
                    title: "Wave Energy",
                    value: String(format: "%.0f", dataStore.currentConditions.waveEnergy),
                    unit: "kJ/m\u{00B2}",
                    icon: "bolt"
                )
            }
        }
        .padding(.horizontal, 6)
    }
}
