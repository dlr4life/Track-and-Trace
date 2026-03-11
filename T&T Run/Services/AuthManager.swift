//
//  AuthManager.swift
//  T&T Run
//
//  Optional ArcGIS Online or Enterprise OAuth sign-in for secured Feature Services.
//  Configure ArcGISEnvironment.authenticationManager with your OAuth config (portal URL, client ID, redirect URL).
//

import Combine
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isSignedIn = false
    @Published private(set) var portalUser: String?

    private init() {}

    /// Call when user enables OAuth and provides portal URL; use to configure ArcGIS challenge handler.
    func configureOAuth(portalURL: URL?) {
        guard portalURL != nil else { return }
        // Configure ArcGIS OAuth: set ArcGISEnvironment.authenticationManager.arcGISAuthenticationChallengeHandler
        // with OAuthUserConfiguration(portalURL:clientID:redirectURL:) for your portal.
    }

    func signOut() {
        isSignedIn = false
        portalUser = nil
        // ArcGISEnvironment.authenticationManager.credentialStore.removeAllCredentials()
    }
}
