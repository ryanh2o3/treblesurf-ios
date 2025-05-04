//
//  SignInView.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct SignInView: View {
    @Binding var isAuthenticated: Bool
    @State private var isSigningIn = false

    var body: some View {
        VStack {
            GoogleSignInButton(action: handleSignInButton)
                .disabled(isSigningIn)
        }
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
            isSigningIn = false
            if let error = error {
                print("Sign-in failed: \(error.localizedDescription)")
                return
            }

            if let result = signInResult {
                AuthManager.shared.authenticateWithBackend(user: result.user) { success, responseData in
                    DispatchQueue.main.async {
                        print ("responseData", responseData)
                        if success {
                            if let responseData = responseData,
                               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                               let csrfToken = json["csrf_token"] as? String {
                                AuthManager.shared.csrfTokenValue = csrfToken
                            }
                            isAuthenticated = true
                        } else {
                            print("Backend authentication failed")
                        }
                    }
                }
            }
        }
    }
}
