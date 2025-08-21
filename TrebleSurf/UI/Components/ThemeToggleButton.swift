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
                    .foregroundColor(.accentColor)
                
                Text(settingsStore.selectedTheme.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ThemeToggleButton()
        .environmentObject(SettingsStore.shared)
}
