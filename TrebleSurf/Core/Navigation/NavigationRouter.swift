import SwiftUI

enum AppDestination: Hashable {
    case home
    case map
    case spotDetail(spotId: String)
    case buoys
    case buoyDetail(buoyId: String)
    case spots
    case liveSpot(spotId: String)
    case surfReport(spotId: String)
}

class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()
    
    func navigate(to destination: AppDestination) {
        path.append(destination)
    }
    
    func navigateBack() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func navigateToRoot() {
        path = NavigationPath()
    }
}
