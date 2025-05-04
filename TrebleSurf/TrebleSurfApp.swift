//
//  TrebleSurfApp.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 03/05/2025.
//

import SwiftUI
import GoogleSignIn

class SettingsStore: ObservableObject {
    @Published var isDarkMode: Bool = false
    // Add other app settings here as needed
}

@main
struct TrebleSurfApp: App {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var dataStore = DataStore()
    @State private var isAuthenticated = false
    @State private var isLoading = true


    var body: some Scene {
        WindowGroup {
                    ZStack {
                        if isLoading {
                            ProgressView("Loading...")
                        } else if isAuthenticated {
                            MainTabView(isAuthenticated: $isAuthenticated)
                                .environmentObject(settingsStore)
                                .preferredColorScheme(settingsStore.isDarkMode ? .dark : .light)
                                .accentColor(.blue)
                                .onOpenURL { url in
                                    GIDSignIn.sharedInstance.handle(url)
                                }.environmentObject(dataStore)
                        } else {
                            SignInView(isAuthenticated: $isAuthenticated)
                        }
                    }
                    .onAppear {
                        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                            if let user = user {
                                print("Restored previous sign-in for user: \(user.profile?.name ?? "Unknown")")
                                isAuthenticated = true
                            } else if let error = error {
                                print("Failed to restore previous sign-in: \(error.localizedDescription)")
                                isAuthenticated = false
                            }
                            isLoading = false
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
        return GIDSignIn.sharedInstance.handle(url)
    }
}
