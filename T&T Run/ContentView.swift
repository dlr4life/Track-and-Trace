//
//  ContentView.swift
//  T&T Run
//
//  Root: map, toolbar, theme, iPad split view, OAuth authenticator.
//

import ArcGIS
import ArcGISToolkit
import SwiftUI

private enum ContentSheetItem: Identifiable {
    case settings
    var id: Self { self }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var settings = AppSettings.shared
    @ObservedObject private var authManager = AuthManager.shared
    @State private var presentedSheet: ContentSheetItem?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                phoneLayout
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .authenticator(authManager.authenticator)
        .task {
            await authManager.setupPersistentCredentialStorage()
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch settings.appTheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    private var phoneLayout: some View {
        TrackMapView(settings: settings, locationManager: locationManager) {
            presentedSheet = .settings
        }
        .sheet(item: $presentedSheet) { _ in
            SettingsView(settings: settings)
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            List {
                Button {
                    presentedSheet = .settings
                } label: {
                    Label(AppCopy.settingsTitle, systemImage: "gearshape.fill")
                }
                .accessibilityLabel(AppCopy.accSettingsButton)
                Text(String(localized: "Map on the right"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(AppCopy.appName)
        } detail: {
            TrackMapView(settings: settings, locationManager: locationManager) {
                presentedSheet = .settings
            }
        }
        .sheet(item: $presentedSheet) { _ in
            SettingsView(settings: settings)
        }
    }
}

#Preview {
    ContentView()
}
