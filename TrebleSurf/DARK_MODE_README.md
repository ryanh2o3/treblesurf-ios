# Dark Mode Implementation

TrebleSurf now supports dark mode with the following features:

## Features

- **Three Theme Modes:**

  - **Light**: Always use light appearance
  - **Dark**: Always use dark appearance
  - **System**: Automatically match device appearance (default)

- **Theme Toggle:**

  - Quick toggle button in the Home view navigation bar
  - Full settings interface in the new Settings tab
  - Smooth animations when switching themes

- **Persistence:**

  - Theme preference is saved and restored between app launches
  - Backward compatible with existing `isDarkMode` property

## Implementation Details

### SettingsStore

The `SettingsStore` class manages theme preferences and provides:

- `selectedTheme`: Current theme mode selection
- `isDarkMode`: Boolean for backward compatibility
- `getPreferredColorScheme()`: Returns the appropriate ColorScheme for SwiftUI
- `toggleTheme()`: Cycles through available themes
- `refreshTheme()`: Manually refreshes the current theme

### SettingsView

A dedicated settings interface accessible via the Settings tab that includes:

- Theme selection with visual indicators
- Quick toggle functionality
- Current theme status display
- App information

### ThemeToggleButton

A reusable component that can be added to any view for quick theme switching.

### ThemeEnvironmentKey

A SwiftUI environment key that provides easy access to the current theme throughout the app:

```swift
@Environment(\.currentTheme) var currentTheme
```

### Color Assets

Custom color assets have been created for consistent theming:

- `Gray950`: Dark background color
- `Blue100`: Light blue accent color
- `Gray200`: Light gray background color

## Usage

### Adding Theme Toggle to Views

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        ThemeToggleButton()
    }
}
```

### Accessing Theme in Views

```swift
@EnvironmentObject var settingsStore: SettingsStore
@Environment(\.colorScheme) var colorScheme
@Environment(\.currentTheme) var currentTheme
```

### Programmatic Theme Changes

```swift
// Switch to specific theme
settingsStore.selectedTheme = .dark

// Toggle through themes
settingsStore.toggleTheme()

// Refresh theme (useful after system changes)
settingsStore.refreshTheme()
```

## Integration

The dark mode system is automatically integrated into the app via:

- `TrebleSurfApp.swift`: App-level theme application with environment key
- `MainTabView.swift`: Settings tab addition
- `MainLayout.swift`: Background color theming
- `ThemeEnvironmentKey.swift`: SwiftUI environment integration

## Technical Notes

- **System Theme Detection**: Uses `UIApplication.didBecomeActiveNotification` and `UIApplication.willEnterForegroundNotification` for reliable theme detection
- **Performance**: Theme changes are optimized with minimal overhead
- **Memory Management**: Proper use of weak references and Combine cancellables
- **UserDefaults**: Theme preferences are automatically persisted

## Future Enhancements

- Custom color schemes for different surf conditions
- Time-based automatic theme switching
- User-defined color preferences
- Accessibility considerations for color-blind users
