//
//  ManagedConfigManager.swift
//  T&T Run
//
//  MDM / managed configuration: prefill Feature Service URL and key settings.
//

import Combine
import Foundation

/// Reads managed app configuration (MDM) or custom URL scheme / QR payload to prefill settings.
@MainActor
final class ManagedConfigManager: ObservableObject {
    static let shared = ManagedConfigManager()

    /// Managed configuration dictionary (from UserDefaults or MDM).
    var managedConfig: [String: Any]? {
        UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed")
    }

    /// Apply managed config to AppSettings (Feature Service URL, etc.).
    func applyToSettings(_ settings: AppSettings) {
        guard let config = managedConfig else { return }
        if let url = config["featureServiceURL"] as? String, !url.isEmpty {
            settings.featureServiceURL = url
        }
        if let layerId = config["featureLayerID"] as? Int {
            settings.featureLayerID = layerId
        }
        if let interval = config["syncIntervalSeconds"] as? Int, (10...300).contains(interval) {
            settings.syncIntervalSeconds = interval
        }
    }

    /// Parse URL (e.g. from QR code or link) like ttrun://config?featureServiceURL=...&featureLayerID=0
    static func applyURL(_ url: URL, to settings: AppSettings) {
        guard let comp = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comp.scheme == "ttrun", comp.host == "config",
              let query = comp.queryItems else { return }
        for item in query {
            switch item.name {
            case "featureServiceURL":
                if let value = item.value?.removingPercentEncoding, !value.isEmpty {
                    settings.featureServiceURL = value
                }
            case "featureLayerID":
                if let value = item.value, let id = Int(value) {
                    settings.featureLayerID = id
                }
            case "syncIntervalSeconds":
                if let value = item.value, let sec = Int(value), (10...300).contains(sec) {
                    settings.syncIntervalSeconds = sec
                }
            default:
                break
            }
        }
    }
}
