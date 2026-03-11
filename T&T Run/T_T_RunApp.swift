//
//  T_T_RunApp.swift
//  T&T Run
//
//  App entry: ArcGIS API key, managed config, URL scheme for QR/config, OAuth challenge handler.
//

import ArcGIS
import SwiftUI

@main
struct T_T_RunApp: SwiftUI.App {
    init() {
        if let key = ProcessInfo.processInfo.environment["ARCGIS_API_KEY"] ?? Bundle.main.object(forInfoDictionaryKey: "ArcGISAPIKey") as? String, !key.isEmpty {
            ArcGISEnvironment.apiKey = APIKey(key)
        }
        Task { @MainActor in
            ManagedConfigManager.shared.applyToSettings(AppSettings.shared)
            AuthManager.shared.applyOAuthConfigFromSettings()
        }
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    ManagedConfigManager.applyURL(url, to: AppSettings.shared)
                }
        }
    }
}
