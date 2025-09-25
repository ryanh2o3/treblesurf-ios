// SharedComponents.swift
import SwiftUI

// MARK: - ReadingCard
struct ReadingCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
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
