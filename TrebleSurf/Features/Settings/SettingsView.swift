import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            List {
                // Theme Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Appearance")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        ForEach(ThemeMode.allCases) { theme in
                            ThemeOptionRow(
                                theme: theme,
                                isSelected: settingsStore.selectedTheme == theme,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        settingsStore.selectedTheme = theme
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Display")
                } footer: {
                    Text("Choose how TrebleSurf should appear. 'System' will automatically match your device's appearance.")
                }
                
                // Quick Theme Toggle Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quick Toggle")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Tap to cycle through themes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                settingsStore.toggleTheme()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: settingsStore.selectedTheme.icon)
                                    .foregroundColor(.accentColor)
                                Text(settingsStore.selectedTheme.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } header: {
                    Text("Quick Actions")
                }
                
                // Current Status Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Theme")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(settingsStore.selectedTheme.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Image(systemName: settingsStore.selectedTheme.icon)
                                .foregroundColor(.accentColor)
                            Text(settingsStore.isDarkMode ? "Dark" : "Light")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                } header: {
                    Text("Status")
                }
                
                // App Info Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Version")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Build")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("1")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ThemeOptionRow: View {
    let theme: ThemeMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: theme.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(theme.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsStore())
}
