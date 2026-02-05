import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0 // Default to Map tab
    @EnvironmentObject var dependencies: AppDependencies

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
        .accentColor(.blue)
        .onAppear {
            // Configure TabView for proper Liquid Glass effect
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor.clear
            
            // Enable Liquid Glass material for tab bar
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            
            // Configure tab bar item appearance for better visibility with Liquid Glass
            let itemAppearance = UITabBarItemAppearance()
            itemAppearance.normal.iconColor = UIColor.systemBlue
            itemAppearance.selected.iconColor = UIColor.systemBlue
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor.systemBlue,
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor.systemBlue,
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]
            appearance.stackedLayoutAppearance = itemAppearance
            
            // Apply the appearance
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
}
