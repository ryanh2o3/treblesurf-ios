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
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}

struct RootView: View {
    @ObservedObject var dependencies: AppDependencies
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var authManager: AuthManager
    
    @State private var isLoading = true
    
    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.settingsStore = dependencies.settingsStore
        self.authManager = dependencies.authManager
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading...")
                    .onAppear {
                        checkAuthenticationState()
                    }
            } else if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(dependencies)
                    .environmentObject(settingsStore)
                    .environmentObject(authManager)
                    .environmentObject(dependencies.dataStore)
                    .environmentObject(dependencies.locationStore)
                    .environmentObject(dependencies.swellPredictionService)
                    .currentTheme(settingsStore.selectedTheme)
                    .accentColor(.blue)
                    .onOpenURL { url in
                        handleOpenURL(url)
                    }
            } else {
                SignInView()
                    .environmentObject(authManager)
            }
        }
        .preferredColorScheme(settingsStore.getPreferredColorScheme())
    }
    
    private func handleOpenURL(_ url: URL) {
        #if DEBUG
        // In debug builds, only handle URLs on physical devices
        // (Google Sign-In doesn't work in simulator)
        if !UIDevice.current.isSimulator {
            GIDSignIn.sharedInstance.handle(url)
        }
        #else
        // In production, always handle URLs
        GIDSignIn.sharedInstance.handle(url)
        #endif
    }
    
    private func checkAuthenticationState() {
        #if DEBUG
        if UIDevice.current.isSimulator {
            // Skip authentication check in simulator (debug builds only)
            isLoading = false
            return
        }
        #endif
        
        // Production builds and physical devices always check authentication
        #if DEBUG
        // Debug: Print current auth state (debug builds only)
        authManager.debugPrintAuthState()
        #endif
        
        // Check if we have any stored authentication data
        if authManager.hasStoredAuthData() {
            // First, try to validate existing session with backend
            Task { @MainActor in
                let (success, _) = await authManager.validateSession()
                if success {
                    self.isLoading = false
                } else {
                    self.checkGoogleSignIn()
                }
            }
        } else {
            checkGoogleSignIn()
        }
    }
    
    private func checkGoogleSignIn() {
        // Try to restore Google Sign-In
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user = user {
                // Now authenticate with backend
                Task { @MainActor in
                    let (_, _) = await authManager.authenticateWithBackend(user: user)
                    // Authentication restoration completed
                    self.isLoading = false
                }
            } else if error != nil {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
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
        #if DEBUG
        // In debug builds, only handle URLs on physical devices
        // (Google Sign-In doesn't work in simulator)
        if UIDevice.current.isSimulator {
            return false
        }
        #endif
        // In production, always handle URLs
        return GIDSignIn.sharedInstance.handle(url)
    }
}
