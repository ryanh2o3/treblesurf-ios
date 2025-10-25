// SharedComponents.swift
import SwiftUI

// MARK: - ReadingCard
struct ReadingCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let iconColor: Color
    
    init(title: String, value: String, unit: String, icon: String, iconColor: Color = .blue) {
        self.title = title
        self.value = value
        self.unit = unit
        self.icon = icon
        self.iconColor = iconColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16) // Increased corner radius for iOS 18 Liquid Glass
                .fill(.ultraThinMaterial) // Use system material instead of custom background
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5) // Use system stroke color
                )
        )
    }
}

// MARK: - Preview
#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        ReadingCard(
            title: "Swell Height",
            value: "2.1",
            unit: "m",
            icon: "water.waves"
        )
        
        ReadingCard(
            title: "Swell Period", 
            value: "12",
            unit: "sec",
            icon: "timer"
        )
    }
    .padding()
}
