import Foundation
import SwiftUI
import Combine

enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "gear"
        }
    }
    
    var description: String {
        switch self {
        case .light: return "Always use light appearance"
        case .dark: return "Always use dark appearance"
        case .system: return "Match device appearance"
        }
    }
}

@MainActor
class SettingsStore: ObservableObject, SettingsStoreProtocol {
    static let shared = SettingsStore()
    
    @Published var selectedTheme: ThemeMode = .system {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
            updateColorScheme()
        }
    }
    
    @Published var isDarkMode: Bool = false {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    @Published var showSwellPredictions: Bool = true {
        didSet {
            UserDefaults.standard.set(showSwellPredictions, forKey: "showSwellPredictions")
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSettings()
        setupThemeObserver()
    }
    
    private func loadSettings() {
        // Load saved theme preference
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = ThemeMode(rawValue: savedTheme) {
            selectedTheme = theme
        }
        
        // Load saved dark mode preference (for backward compatibility)
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        
        // Load swell predictions preference (default to true)
        showSwellPredictions = UserDefaults.standard.object(forKey: "showSwellPredictions") as? Bool ?? true
        
        updateColorScheme()
    }
    
    private func setupThemeObserver() {
        // Observe system theme changes when in system mode
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.updateColorScheme()
            }
            .store(in: &cancellables)
        
        // Also observe when the app comes to foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.updateColorScheme()
            }
            .store(in: &cancellables)
    }
    
    private func updateColorScheme() {
        switch selectedTheme {
        case .light:
            isDarkMode = false
        case .dark:
            isDarkMode = true
        case .system:
            // Get current system appearance
            let currentAppearance = UIScreen.main.traitCollection.userInterfaceStyle
            isDarkMode = currentAppearance == .dark
        }
    }
    
    func getPreferredColorScheme() -> ColorScheme? {
        switch selectedTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil // Let system decide
        }
    }
    
    func toggleTheme() {
        let currentIndex = ThemeMode.allCases.firstIndex(of: selectedTheme) ?? 0
        let nextIndex = (currentIndex + 1) % ThemeMode.allCases.count
        selectedTheme = ThemeMode.allCases[nextIndex]
    }
    
    func refreshTheme() {
        updateColorScheme()
    }
    
    /// Reset the store to its initial state - resets theme preferences
    func resetToInitialState() {
        // Already on MainActor, no need for DispatchQueue
        // Reset to system theme (default)
        self.selectedTheme = .system
        self.isDarkMode = false
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "selectedTheme")
        UserDefaults.standard.removeObject(forKey: "isDarkMode")
        UserDefaults.standard.removeObject(forKey: "showSwellPredictions")
        UserDefaults.standard.synchronize()
        
        // Update color scheme
        self.updateColorScheme()
        
        print("SettingsStore reset to initial state")
    }
}
