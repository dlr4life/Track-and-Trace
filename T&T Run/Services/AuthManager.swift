//
//  AuthManager.swift
//  T&T Run
//
//  ArcGIS OAuth sign-in using ArcGIS Toolkit's Authenticator and persistent credential store.
//  Portal URL, Use OAuth, Client ID, and Redirect URL are in Settings; configureOAuth/signOut are wired to the Portal section.
//

import ArcGIS
import ArcGISToolkit
import Combine
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isSignedIn = false
    @Published private(set) var portalUser: String?

    /// Toolkit Authenticator for OAuth UI and challenge handling. Always non-nil (empty config when OAuth is off).
    private(set) var authenticator: Authenticator = Authenticator(oAuthUserConfigurations: [])

    private init() {}

    /// Applies OAuth configuration from AppSettings (e.g. at app launch). Call from T_T_RunApp init.
    func applyOAuthConfigFromSettings() {
        let settings = AppSettings.shared
        guard settings.useOAuth else {
            configureOAuth(portalURL: nil, clientID: nil, redirectURL: nil)
            return
        }
        configureOAuth(
            portalURL: settings.resolvedPortalURL,
            clientID: settings.oauthClientID.isEmpty ? nil : settings.oauthClientID,
            redirectURL: settings.resolvedOauthRedirectURL
        )
    }

    /// Call when user enables OAuth and provides portal URL, client ID, and redirect URL from Settings.
    /// Creates or updates the Toolkit Authenticator and sets it as the ArcGIS challenge handler.
    func configureOAuth(portalURL: URL?, clientID: String?, redirectURL: URL?) {
        if let portalURL = portalURL,
           let clientID = clientID, !clientID.isEmpty,
           let redirectURL = redirectURL {
            let config = OAuthUserConfiguration(
                portalURL: portalURL,
                clientID: clientID,
                redirectURL: redirectURL
            )
            authenticator = Authenticator(oAuthUserConfigurations: [config])
            ArcGISEnvironment.authenticationManager.handleChallenges(using: authenticator)
            updateSignInState()
        } else {
            authenticator = Authenticator(oAuthUserConfigurations: [])
            ArcGISEnvironment.authenticationManager.handleChallenges(using: nil)
            isSignedIn = false
            portalUser = nil
        }
    }

    func signOut() {
        isSignedIn = false
        portalUser = nil
        Task {
            await ArcGISEnvironment.authenticationManager.signOut()
            await MainActor.run {
                isSignedIn = false
                portalUser = nil
            }
        }
    }

    /// Sets up persistent credential storage (keychain). Call once at app launch.
    func setupPersistentCredentialStorage() async {
        do {
            try await ArcGISEnvironment.authenticationManager.setupPersistentCredentialStorage(access: .whenUnlocked)
        } catch {
            // Log or surface if needed
        }
    }

    /// Updates isSignedIn and portalUser from the current ArcGIS credential store.
    func updateSignInState() {
        Task {
            let store = ArcGISEnvironment.authenticationManager.arcGISCredentialStore
            let credentials = store.credentials
            let hasOAuth = credentials.contains { $0 is OAuthUserCredential }
            await MainActor.run {
                isSignedIn = hasOAuth
                if hasOAuth, let oauth = credentials.first(where: { $0 is OAuthUserCredential }) as? OAuthUserCredential {
                    portalUser = oauth.username
                } else {
                    portalUser = nil
                }
            }
        }
    }
}
