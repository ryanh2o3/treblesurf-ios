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
                        .environmentObject(dataStore)
                } else {
                    SignInView()
                        .environmentObject(authManager)
                }
            }
        }
    }
    
    private func checkAuthenticationState() {
        #if DEBUG
        if UIDevice.current.isSimulator {
            // Skip authentication check in simulator (debug builds only)
            print("Running in simulator - skipping authentication")
            isLoading = false
            return
        }
        #endif
        
        // Production builds and physical devices always check authentication
        print("Running on device - checking authentication state")
        
        #if DEBUG
        // Debug: Print current auth state (debug builds only)
        AuthManager.shared.debugPrintAuthState()
        #endif
        
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
    
    private func checkGoogleSignIn() {
        // Try to restore Google Sign-In
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user = user {
                print("Restored previous Google Sign-In for user: \(user.profile?.name ?? "Unknown")")
                
                // Now authenticate with backend
                Task { @MainActor in
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
                }
            } else if let error = error {
                print("Failed to restore previous sign-in: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            } else {
                print("No previous sign-in found")
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
