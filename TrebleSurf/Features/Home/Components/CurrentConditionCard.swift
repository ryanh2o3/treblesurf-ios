import SwiftUI

struct CurrentConditionCard: View {
    let condition: CurrentCondition

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Conditions")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text(condition.waveHeight)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Wave Height")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("\(condition.windDirection) \(condition.windSpeed)")
                        .font(.title3)
                    Text("Wind")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text(condition.temperature)
                        .font(.title3)
                    Text("Temp")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(condition.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        )
        .padding(.horizontal)
    }
}
