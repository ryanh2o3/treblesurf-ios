import SwiftUI

struct MainLayout<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
                .ignoresSafeArea()
            
            // Content
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    var backgroundGradient: some View {
        Group {
            if colorScheme == .dark {
                Color("Gray950")
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color("Blue100").opacity(0.1),
                        Color("Gray200").opacity(0.7),
                        Color("Blue100").opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}
