import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0 // Default to Map tab
    @EnvironmentObject var dependencies: AppDependencies
    @EnvironmentObject var settingsStore: SettingsStore
    @Environment(\.colorScheme) var systemColorScheme
    
    /// Unique identifier that changes when theme changes, forcing TabView recreation
    @State private var tabViewId = UUID()
    
    /// Computes the effective color scheme based on the user's theme selection
    private var effectiveColorScheme: ColorScheme {
        switch settingsStore.selectedTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return systemColorScheme
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(dependencies: dependencies)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            MapView(dependencies: dependencies)
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(1)
            
            BuoysView(dependencies: dependencies)
                .tabItem {
                    Label("Buoys", systemImage: "water.waves")
                }
                .tag(2)
            
            SpotsView(dependencies: dependencies)
                .tabItem {
                    Label("Spots", systemImage: "mappin")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .id(tabViewId) // Force TabView recreation when this changes
        .onAppear {
            configureTabBarAppearance(for: effectiveColorScheme)
        }
        .onChange(of: settingsStore.selectedTheme) {
            // Configure new appearance first, then recreate TabView to pick it up
            configureTabBarAppearance(for: effectiveColorScheme)
            // Force TabView to recreate with new appearance
            tabViewId = UUID()
        }
        .onChange(of: systemColorScheme) {
            // Also react to system theme changes (for .system mode)
            if settingsStore.selectedTheme == .system {
                configureTabBarAppearance(for: effectiveColorScheme)
                tabViewId = UUID()
            }
        }
    }
    
    private func configureTabBarAppearance(for scheme: ColorScheme) {
        // Configure TabView for proper Liquid Glass effect
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.clear
        
        // Enable Liquid Glass material for tab bar - explicitly match the color scheme
        let blurStyle: UIBlurEffect.Style = scheme == .dark ? .systemThinMaterialDark : .systemThinMaterialLight
        appearance.backgroundEffect = UIBlurEffect(style: blurStyle)
        
        // Configure tab bar item appearance for better visibility with Liquid Glass
        let itemAppearance = UITabBarItemAppearance()
        
        // Use system blue for both modes, or white/black depending on what creates better contrast
        let iconColor = UIColor.systemBlue
        
        itemAppearance.normal.iconColor = iconColor.withAlphaComponent(0.6)
        itemAppearance.selected.iconColor = iconColor
        
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: iconColor.withAlphaComponent(0.6),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: iconColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance = itemAppearance
        
        // Apply the appearance globally so new TabView instances pick it up
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // Ensure tab bar is completely transparent
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().barTintColor = UIColor.clear
        UITabBar.appearance().backgroundColor = UIColor.clear
        
        // Remove any shadow or border that might create visual artifacts
        UITabBar.appearance().shadowImage = UIImage()
        UITabBar.appearance().backgroundImage = UIImage()
    }
}
