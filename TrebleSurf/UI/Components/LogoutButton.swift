//
//  LogoutButton.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import SwiftUI

struct LogoutButton: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoggingOut = false
    @State private var showLogoutAlert = false
    
    var body: some View {
        Button(action: {
            showLogoutAlert = true
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))
                Text("Sign Out")
            }
            .foregroundColor(.red)
        }
        .disabled(isLoggingOut)
        .overlay {
            if isLoggingOut {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            }
        }
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                handleLogout()
            }
        } message: {
            Text("This will sign you out and clear all app data including saved locations, preferences, and cached information. This action cannot be undone.")
        }
    }
    
    private func handleLogout() {
        isLoggingOut = true
        
        Task { @MainActor in
            let success = await authManager.logout()
            isLoggingOut = false
            if success {
                print("Successfully logged out and cleared all app data")
                // You might want to navigate to the sign-in screen here
                // or trigger a navigation reset
            } else {
                print("Logout failed")
                // Even if logout fails, the local data should still be cleared
            }
        }
    }
}

#Preview {
    LogoutButton()
        .environmentObject(AuthManager())
}
