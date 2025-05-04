import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @Binding var isAuthenticated: Bool

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(1)
            
            BuoysView()
                .tabItem {
                    Label("Buoys", systemImage: "water.waves")
                }
                .tag(2)
            
            SpotsView()
                .tabItem {
                    Label("Spots", systemImage: "mappin")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}
