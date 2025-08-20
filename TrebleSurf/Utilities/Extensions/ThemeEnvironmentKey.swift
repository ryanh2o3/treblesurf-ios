import SwiftUI

struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeMode = .system
}

extension EnvironmentValues {
    var currentTheme: ThemeMode {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

extension View {
    func currentTheme(_ theme: ThemeMode) -> some View {
        environment(\.currentTheme, theme)
    }
}
