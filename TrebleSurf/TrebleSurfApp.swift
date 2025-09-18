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
    @StateObject private var settingsStore = SettingsStore.shared
    @StateObject private var dataStore = DataStore.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var isLoading = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading {
                    ProgressView("Loading...")
                        .onAppear {
                            checkAuthenticationState()
                        }
                } else if authManager.isAuthenticated {
                    MainTabView()
                        .environmentObject(settingsStore)
                        .environmentObject(authManager)
                        .currentTheme(settingsStore.selectedTheme)
                        .preferredColorScheme(settingsStore.getPreferredColorScheme())
                        .accentColor(.blue)
                        .onOpenURL { url in
                            if !UIDevice.current.isSimulator {
                                GIDSignIn.sharedInstance.handle(url)
                            }
                        }
                        .environmentObject(dataStore)
                } else {
                    SignInView()
                        .environmentObject(authManager)
                }
            }
        }
    }
    
    private func checkAuthenticationState() {
        if UIDevice.current.isSimulator {
            // Skip authentication check in simulator
            print("Running in simulator - skipping authentication")
            isLoading = false
        } else {
            print("Running on device - checking authentication state")
            
            // Debug: Print current auth state
            AuthManager.shared.debugPrintAuthState()
            
            // Check if we have any stored authentication data
            if AuthManager.shared.hasStoredAuthData() {
                print("Found stored authentication data, attempting to validate session")
                
                // First, try to validate existing session with backend
                AuthManager.shared.validateSession { success, user in
                    DispatchQueue.main.async {
                        if success {
                            print("Successfully validated existing session for user: \(user?.email ?? "Unknown")")
                            self.isLoading = false
                        } else {
                            print("Session validation failed, checking for Google Sign-In")
                            self.checkGoogleSignIn()
                        }
                    }
                }
            } else {
                print("No stored authentication data found, checking for Google Sign-In")
                checkGoogleSignIn()
            }
        }
    }
    
    private func checkGoogleSignIn() {
        // Try to restore Google Sign-In
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user = user {
                print("Restored previous Google Sign-In for user: \(user.profile?.name ?? "Unknown")")
                
                // Now authenticate with backend
                AuthManager.shared.authenticateWithBackend(user: user) { success, _ in
                    DispatchQueue.main.async {
                        if success {
                            print("Successfully restored authentication")
                        } else {
                            print("Failed to restore backend authentication")
                        }
                        self.isLoading = false
                    }
                }
            } else if let error = error {
                print("Failed to restore previous sign-in: \(error.localizedDescription)")
                self.isLoading = false
            } else {
                print("No previous sign-in found")
                self.isLoading = false
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
