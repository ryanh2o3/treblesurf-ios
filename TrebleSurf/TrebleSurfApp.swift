//
//  TrebleSurfApp.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 03/05/2025.
//

import SwiftUI
import GoogleSignIn

@main
struct TrebleSurfApp: App {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var dataStore = DataStore()
    @State private var isAuthenticated = false
    @State private var isLoading = true
    @State private var authError: String?

    var body: some Scene {
        WindowGroup {
                    ZStack {
                        if isLoading {
                            ProgressView("Loading...")
                        } else if isAuthenticated {
                            MainTabView(isAuthenticated: $isAuthenticated)
                                .environmentObject(settingsStore)
                                .currentTheme(settingsStore.selectedTheme)
                                .preferredColorScheme(settingsStore.getPreferredColorScheme())
                                .accentColor(.blue)
                                .onOpenURL { url in
                                    if !UIDevice.current.isSimulator {
                                        GIDSignIn.sharedInstance.handle(url)
                                    }
                                }.environmentObject(dataStore)
                        } else {
                            SignInView(isAuthenticated: $isAuthenticated)
                        }
                    }
                    .onAppear {
                        checkAuthenticationState()
                    }
                }
        
    }
    
    private func checkAuthenticationState() {
        if UIDevice.current.isSimulator {
            // Skip Google sign-in restoration in simulator
            print("Running in simulator - skipping authentication")
            print("AuthManager state:")
            AuthManager.shared.printAuthState()
            isLoading = false
            isAuthenticated = false
        } else {
            print("Running on device - attempting to restore authentication")
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let user = user {
                    print("Restored previous sign-in for user: \(user.profile?.name ?? "Unknown")")
                    isAuthenticated = true
                    // Print authentication state after successful restoration
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        AuthManager.shared.printAuthState()
                    }
                } else if let error = error {
                    print("Failed to restore previous sign-in: \(error.localizedDescription)")
                    isAuthenticated = false
                    authError = error.localizedDescription
                } else {
                    print("No previous sign-in found")
                    isAuthenticated = false
                }
                isLoading = false
            }
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ app: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Google Sign-In
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if UIDevice.current.isSimulator {
            return false
        }
        return GIDSignIn.sharedInstance.handle(url)
        }
}
