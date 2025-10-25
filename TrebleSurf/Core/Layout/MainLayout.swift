import SwiftUI

struct MainLayout<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Background - simplified for Liquid Glass compatibility
            backgroundGradient
                .ignoresSafeArea(.all)
            
            // Content with proper safe area handling
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground)) // Ensure system background extends everywhere
    }
    
    var backgroundGradient: some View {
        // Use pure system background for optimal Liquid Glass integration
        Color(.systemBackground)
    }
}
