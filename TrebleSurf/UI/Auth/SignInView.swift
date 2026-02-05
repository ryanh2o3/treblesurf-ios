//
//  SignInView.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import UIKit

struct SignInView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isSigningIn = false
    @State private var showDevSignIn = false
    @State private var devEmail = ""

    var body: some View {
        VStack(spacing: 20) {
            // App Logo/Title
            VStack(spacing: 16) {
                Image(systemName: "wave.3.right")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text("TrebleSurf")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your surf companion")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            #if DEBUG
            if UIDevice.current.isSimulator {
                // Simulator Mode - Only available in debug builds
                VStack(spacing: 16) {
                    Image(systemName: "iphone.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Google Sign-In Disabled")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Google Sign-In is not available in the iOS Simulator. Use development mode to test the app.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Development Sign-In") {
                        showDevSignIn = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                // Device Mode
                VStack(spacing: 16) {
                    GoogleSignInButton(action: handleSignInButton)
                        .disabled(isSigningIn)
                    
                    if isSigningIn {
                        ProgressView("Signing in...")
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
            }
            #else
            // Production Mode - Always show Google Sign-In
            VStack(spacing: 16) {
                GoogleSignInButton(action: handleSignInButton)
                    .disabled(isSigningIn)
                
                if isSigningIn {
                    ProgressView("Signing in...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            #endif
            
            Spacer()
        }
        .padding()
        #if DEBUG
        .sheet(isPresented: $showDevSignIn) {
            DevSignInView()
        }
        #endif
    }

    func handleSignInButton() {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            print("Unable to get root view controller")
            return
        }

        isSigningIn = true
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            DispatchQueue.main.async {
                isSigningIn = false
                
                if let error = error {
                    print("Sign-in failed: \(error.localizedDescription)")
                    return
                }

                if let result = signInResult {
                    Task { @MainActor in
                        let (success, user) = await authManager.authenticateWithBackend(user: result.user)
                        if success {
                            print("Successfully authenticated user: \(user?.email ?? "Unknown")")
                        } else {
                            print("Backend authentication failed")
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
// MARK: - Development Sign-In View
// This view is only available in debug builds for testing purposes
struct DevSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var email = "dev@treblesurf.com"
    @State private var isSigningIn = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Development Mode")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create a development session for testing purposes. This bypasses Google authentication.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.headline)
                    
                    TextField("Enter email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Button("Create Development Session") {
                    createDevSession()
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || isSigningIn)
                
                if isSigningIn {
                    ProgressView("Creating session...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Dev Sign-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createDevSession() {
        isSigningIn = true
        
        Task { @MainActor in
            let success = await authManager.createDevSession(email: email)
            isSigningIn = false
            if success {
                dismiss()
            }
        }
    }
}
#endif

#Preview {
    SignInView()
        .environmentObject(AuthManager())
}
