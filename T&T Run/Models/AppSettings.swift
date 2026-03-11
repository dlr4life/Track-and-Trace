//
//  AppSettings.swift
//  T&T Run
//
//  Central app settings: feature service, basemap, sync interval, layer ID,
//  theme, power saver, privacy, multiple services, attribute mapping, etc.
//

import Combine
import Foundation
import SwiftUI
import ArcGIS

// MARK: - App theme (dark / light / system)

enum AppThemeOption: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }
}

// MARK: - Basemap choice (maps to ArcGIS Basemap.Style)

enum AppBasemapStyle: String, CaseIterable, Identifiable {
    case streets = "streets"
    case topographic = "topographic"
    case satellite = "satellite"
    case navigation = "navigation"
    case darkGray = "darkGray"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .streets: return String(localized: "Streets")
        case .topographic: return String(localized: "Topographic")
        case .satellite: return String(localized: "Satellite")
        case .navigation: return String(localized: "Navigation")
        case .darkGray: return String(localized: "Dark Gray")
        }
    }

    var arcGISStyle: ArcGIS.Basemap.Style {
        switch self {
        case .streets: return .arcGISStreets
        case .topographic: return .arcGISTopographic
        case .satellite: return .arcGISImagery
        case .navigation: return .arcGISNavigation
        case .darkGray: return .arcGISDarkGray
        }
    }
}

// MARK: - App settings (observable, persisted)

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let featureServiceURL = "app.featureServiceURL"
        static let featureLayerID = "app.featureLayerID"
        static let syncIntervalSeconds = "app.syncIntervalSeconds"
        static let basemapStyle = "app.basemapStyle"
        static let appTheme = "app.theme"
        static let powerSaverMode = "app.powerSaverMode"
        static let trackingPaused = "app.trackingPaused"
        static let currentSessionId = "app.currentSessionId"
        static let currentRouteName = "app.currentRouteName"
        static let attributeMapping = "app.attributeMapping"
        static let featureServiceConfigs = "app.featureServiceConfigs"
        static let useStreamLayer = "app.useStreamLayer"
        static let privacyNoticeAccepted = "app.privacyNoticeAccepted"
        static let portalURL = "app.portalURL"
        static let useOAuth = "app.useOAuth"
        static let useClustering = "app.useClustering"
        static let offlineBasemapPath = "app.offlineBasemapPath"
    }

    /// Feature Service URL for track/asset layer (legacy single service). Empty = sync disabled.
    @Published var featureServiceURL: String {
        didSet { defaults.set(featureServiceURL, forKey: Keys.featureServiceURL) }
    }

    /// Layer index in the feature service (typically 0).
    @Published var featureLayerID: Int {
        didSet { defaults.set(featureLayerID, forKey: Keys.featureLayerID) }
    }

    /// How often to push location to the feature service (seconds). Clamped to 10–300.
    @Published var syncIntervalSeconds: Int {
        didSet {
            let clamped = min(300, max(10, syncIntervalSeconds))
            if clamped != syncIntervalSeconds { syncIntervalSeconds = clamped }
            defaults.set(syncIntervalSeconds, forKey: Keys.syncIntervalSeconds)
        }
    }

    /// Selected basemap style.
    @Published var basemapStyle: AppBasemapStyle {
        didSet { defaults.set(basemapStyle.rawValue, forKey: Keys.basemapStyle) }
    }

    /// App-level theme: system, light, or dark.
    @Published var appTheme: AppThemeOption {
        didSet { defaults.set(appTheme.rawValue, forKey: Keys.appTheme) }
    }

    /// Power saver: longer sync interval and reduced location accuracy when enabled.
    @Published var powerSaverMode: Bool {
        didSet { defaults.set(powerSaverMode, forKey: Keys.powerSaverMode) }
    }

    /// User-paused tracking (privacy); when true, do not record or sync location.
    @Published var trackingPaused: Bool {
        didSet {
            defaults.set(trackingPaused, forKey: Keys.trackingPaused)
            NotificationCenter.default.post(name: .trackingPausedDidChange, object: nil)
        }
    }

    /// Current run/route session ID for tagging points.
    @Published var currentSessionId: UUID? {
        didSet {
            defaults.set(currentSessionId?.uuidString, forKey: Keys.currentSessionId)
        }
    }

    /// Current route/session display name.
    @Published var currentRouteName: String {
        didSet { defaults.set(currentRouteName, forKey: Keys.currentRouteName) }
    }

    /// Custom attribute mapping for Feature Service fields.
    @Published var attributeMapping: AttributeMapping {
        didSet {
            if let data = try? JSONEncoder().encode(attributeMapping) {
                defaults.set(data, forKey: Keys.attributeMapping)
            }
        }
    }

    /// Multiple Feature Service / layer configs (for multiple layers support).
    @Published var featureServiceConfigs: [FeatureServiceConfig] {
        didSet {
            if let data = try? JSONEncoder().encode(featureServiceConfigs) {
                defaults.set(data, forKey: Keys.featureServiceConfigs)
            }
        }
    }

    /// Use ArcGIS Stream Layer for low-latency updates when backend supports it.
    @Published var useStreamLayer: Bool {
        didSet { defaults.set(useStreamLayer, forKey: Keys.useStreamLayer) }
    }

    /// User has accepted the in-app privacy notice.
    @Published var privacyNoticeAccepted: Bool {
        didSet { defaults.set(privacyNoticeAccepted, forKey: Keys.privacyNoticeAccepted) }
    }

    /// ArcGIS Portal URL for OAuth sign-in (optional).
    @Published var portalURL: String {
        didSet { defaults.set(portalURL, forKey: Keys.portalURL) }
    }

    /// Use OAuth portal sign-in for secured services.
    @Published var useOAuth: Bool {
        didSet { defaults.set(useOAuth, forKey: Keys.useOAuth) }
    }

    /// Use feature clustering when many assets are visible.
    @Published var useClustering: Bool {
        didSet { defaults.set(useClustering, forKey: Keys.useClustering) }
    }

    /// Path to offline basemap package (e.g. .tpk or .vtpk) when available.
    @Published var offlineBasemapPath: String {
        didSet { defaults.set(offlineBasemapPath, forKey: Keys.offlineBasemapPath) }
    }

    init() {
        self.featureServiceURL = defaults.string(forKey: Keys.featureServiceURL) ?? ""
        self.featureLayerID = defaults.object(forKey: Keys.featureLayerID) as? Int ?? 0
        self.syncIntervalSeconds = defaults.object(forKey: Keys.syncIntervalSeconds) as? Int ?? 30
        let raw = defaults.string(forKey: Keys.basemapStyle) ?? AppBasemapStyle.streets.rawValue
        self.basemapStyle = AppBasemapStyle(rawValue: raw) ?? .streets
        let themeRaw = defaults.string(forKey: Keys.appTheme) ?? AppThemeOption.system.rawValue
        self.appTheme = AppThemeOption(rawValue: themeRaw) ?? .system
        self.powerSaverMode = defaults.bool(forKey: Keys.powerSaverMode)
        self.trackingPaused = defaults.bool(forKey: Keys.trackingPaused)
        self.currentSessionId = (defaults.string(forKey: Keys.currentSessionId)).flatMap { UUID(uuidString: $0) }
        self.currentRouteName = defaults.string(forKey: Keys.currentRouteName) ?? ""
        if let data = defaults.data(forKey: Keys.attributeMapping),
           let decoded = try? JSONDecoder().decode(AttributeMapping.self, from: data) {
            self.attributeMapping = decoded
        } else {
            self.attributeMapping = .default
        }
        if let data = defaults.data(forKey: Keys.featureServiceConfigs),
           let decoded = try? JSONDecoder().decode([FeatureServiceConfig].self, from: data) {
            self.featureServiceConfigs = decoded
        } else {
            self.featureServiceConfigs = []
        }
        self.useStreamLayer = defaults.bool(forKey: Keys.useStreamLayer)
        self.privacyNoticeAccepted = defaults.bool(forKey: Keys.privacyNoticeAccepted)
        self.portalURL = defaults.string(forKey: Keys.portalURL) ?? ""
        self.useOAuth = defaults.bool(forKey: Keys.useOAuth)
        self.useClustering = defaults.bool(forKey: Keys.useClustering)
        self.offlineBasemapPath = defaults.string(forKey: Keys.offlineBasemapPath) ?? ""
    }

    /// Resolved feature service URL for sync (legacy single URL); nil if empty or invalid.
    var resolvedFeatureServiceURL: URL? {
        if !featureServiceConfigs.isEmpty, let first = featureServiceConfigs.first?.resolvedURL {
            return first
        }
        let trimmed = featureServiceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        return url
    }

    /// All configs that have a valid URL (for multiple layers). Falls back to legacy URL + layer ID when list is empty.
    var activeFeatureServiceConfigs: [FeatureServiceConfig] {
        if !featureServiceConfigs.isEmpty {
            return featureServiceConfigs.filter { $0.resolvedURL != nil }
        }
        if let _ = resolvedFeatureServiceURL {
            return [FeatureServiceConfig(label: String(localized: "Default"), serviceURL: featureServiceURL, layerID: featureLayerID)]
        }
        return []
    }

    /// Effective sync interval in seconds (longer in power saver).
    var effectiveSyncIntervalSeconds: Int {
        powerSaverMode ? min(300, syncIntervalSeconds * 2) : syncIntervalSeconds
    }
}

extension Notification.Name {
    static let trackingPausedDidChange = Notification.Name("trackingPausedDidChange")
}
