//
//  MainTabView.swift
//  T&T Run
//
//  Main tab container: Home and Map. Shown after splash (and onboarding when applicable).
//

import ArcGIS
import ArcGISToolkit
import SwiftUI

struct MainTabView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var settings = AppSettings.shared
    @ObservedObject private var authManager = AuthManager.shared
    @State private var selectedTab: MainTab = .home
    @State private var presentedSheet: MainTabSheetItem?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    enum MainTab: Int, CaseIterable {
        case home = 0
        case map = 1
    }

    private enum MainTabSheetItem: Identifiable {
        case settings
        var id: Self { self }
    }

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
        .sheet(item: $presentedSheet) { _ in
            SettingsView(settings: settings)
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
        TabView(selection: $selectedTab) {
            HomeView(
                settings: settings,
                onOpenMap: { selectedTab = .map },
                onOpenSettings: { presentedSheet = .settings }
            )
            .tabItem {
                Label(String(localized: "Home"), systemImage: "house.fill")
            }
            .tag(MainTab.home)

            mapTabContent
                .tabItem {
                    Label(AppCopy.mapTitle, systemImage: "map.fill")
                }
                .tag(MainTab.map)
        }
    }

    private var mapTabContent: some View {
        TrackMapView(settings: settings, locationManager: locationManager) {
            presentedSheet = .settings
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            List {
                Button {
                    selectedTab = .home
                } label: {
                    Label(String(localized: "Home"), systemImage: "house.fill")
                }
                .listRowBackground(selectedTab == .home ? Color.accentColor.opacity(0.2) : nil)
                Button {
                    selectedTab = .map
                } label: {
                    Label(AppCopy.mapTitle, systemImage: "map.fill")
                }
                .listRowBackground(selectedTab == .map ? Color.accentColor.opacity(0.2) : nil)
                Button {
                    presentedSheet = .settings
                } label: {
                    Label(AppCopy.settingsTitle, systemImage: "gearshape.fill")
                }
                .accessibilityLabel(AppCopy.accSettingsButton)
            }
            .navigationTitle(AppCopy.appName)
        } detail: {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(
                        settings: settings,
                        onOpenMap: { selectedTab = .map },
                        onOpenSettings: { presentedSheet = .settings }
                    )
                case .map:
                    mapTabContent
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}
