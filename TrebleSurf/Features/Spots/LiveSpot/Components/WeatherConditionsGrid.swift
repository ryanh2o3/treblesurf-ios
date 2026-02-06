// WeatherConditionsGrid.swift
import SwiftUI

struct WeatherConditionsGrid: View {
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        // Weather conditions grid
        VStack(alignment: .leading, spacing: 6) {
            Text("Weather Conditions")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ReadingCard(
                    title: "Wind Speed",
                    value: String(format: "%.1f", dataStore.currentConditions.windSpeed),
                    unit: "km/h",
                    icon: "wind"
                )

                ReadingCard(
                    title: "Wind Direction",
                    value: String(format: "%.0f", dataStore.currentConditions.windDirection),
                    unit: "\u{00B0}",
                    icon: "arrow.up.right"
                )

                ReadingCard(
                    title: "Temperature",
                    value: String(format: "%.1f", dataStore.currentConditions.temperature),
                    unit: "\u{00B0}C",
                    icon: "thermometer"
                )

                ReadingCard(
                    title: "Water Temp",
                    value: String(format: "%.1f", dataStore.currentConditions.waterTemperature),
                    unit: "\u{00B0}C",
                    icon: "thermometer.sun"
                )

                ReadingCard(
                    title: "Humidity",
                    value: String(format: "%.0f", dataStore.currentConditions.humidity),
                    unit: "%",
                    icon: "humidity"
                )

                ReadingCard(
                    title: "Pressure",
                    value: String(format: "%.0f", dataStore.currentConditions.pressure),
                    unit: "hPa",
                    icon: "gauge"
                )
            }
        }
        .padding(.horizontal, 6)

        // Additional conditions
        VStack(alignment: .leading, spacing: 6) {
            Text("Additional Info")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ReadingCard(
                    title: "Precipitation",
                    value: String(format: "%.1f", dataStore.currentConditions.precipitation),
                    unit: "mm",
                    icon: "cloud.rain"
                )

                ReadingCard(
                    title: "Swell Height",
                    value: String(format: "%.1f", dataStore.currentConditions.swellHeight),
                    unit: "m",
                    icon: "water.waves"
                )

                ReadingCard(
                    title: "Direction Quality",
                    value: String(format: "%.1f", dataStore.currentConditions.directionQuality),
                    unit: "",
                    icon: "star"
                )

                ReadingCard(
                    title: "Last Updated",
                    value: dataStore.relativeTimeDisplay,
                    unit: "",
                    icon: "clock"
                )
            }
        }
        .padding(.horizontal, 6)
    }
}
