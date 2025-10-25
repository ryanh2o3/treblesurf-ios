import SwiftUI

struct ThemeToggleButton: View {
    @EnvironmentObject var settingsStore: SettingsStore
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                settingsStore.toggleTheme()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: settingsStore.selectedTheme.icon)
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text(settingsStore.selectedTheme.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.quaternary, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle()) // Use plain button style for better compatibility
    }
}

#Preview {
    ThemeToggleButton()
        .environmentObject(SettingsStore.shared)
}
