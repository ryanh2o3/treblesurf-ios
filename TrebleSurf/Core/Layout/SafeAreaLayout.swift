import SwiftUI

struct SafeAreaLayout<Content: View>: View {
    let content: Content
    let edges: Edge.Set
    
    init(edges: Edge.Set = .all, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.edges = edges
    }
    
    var body: some View {
        content
            .padding(getSafeAreaInsets(edges))
    }
    
    private func getSafeAreaInsets(_ edges: Edge.Set) -> EdgeInsets {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return EdgeInsets()
        }
        
        let safeAreaInsets = window.safeAreaInsets
        
        var edgeInsets = EdgeInsets()
        if edges.contains(.top) {
            edgeInsets.top = safeAreaInsets.top
        }
        if edges.contains(.bottom) {
            edgeInsets.bottom = safeAreaInsets.bottom
        }
        if edges.contains(.leading) {
            edgeInsets.leading = safeAreaInsets.left
        }
        if edges.contains(.trailing) {
            edgeInsets.trailing = safeAreaInsets.right
        }
        
        return edgeInsets
    }
}
