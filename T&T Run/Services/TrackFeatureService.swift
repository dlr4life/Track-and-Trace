//
//  TrackFeatureService.swift
//  T&T Run
//
//  Sends track points to ArcGIS Feature Services with retry/backoff, attribute mapping, and optional clustering.
//

import ArcGIS
import Combine
import Foundation
import UIKit

/// Sends GPS track points to an ArcGIS Feature Service; supports custom attribute mapping and clustering.
@MainActor
final class TrackFeatureService: ObservableObject {
    let serviceURL: URL
    let layerID: Int
    var attributeMapping: AttributeMapping

    @Published private(set) var featureTable: ServiceFeatureTable?
    @Published private(set) var featureLayer: FeatureLayer?
    @Published private(set) var loadError: Error?
    @Published private(set) var lastSyncError: Error?
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var isLoaded = false

    private var serviceGeodatabase: ServiceGeodatabase?
    private var retryCount = 0
    private let maxRetries = 5
    private let baseBackoffSeconds: UInt64 = 2

    init(serviceURL: URL, layerID: Int = 0, attributeMapping: AttributeMapping? = nil) {
        self.serviceURL = serviceURL
        self.layerID = layerID
        self.attributeMapping = attributeMapping ?? AttributeMapping.default
    }

    /// Load the feature service and create the feature layer; optionally enable clustering.
    func load(enableClustering: Bool = false) async {
        loadError = nil
        let geodatabase = ServiceGeodatabase(url: serviceURL)
        do {
            try await geodatabase.load()
            guard let table = geodatabase.table(withLayerID: layerID) else {
                throw TrackFeatureServiceError.layerNotFound(layerID)
            }
            serviceGeodatabase = geodatabase
            featureTable = table
            let layer = FeatureLayer(featureTable: table)
            if enableClustering {
                let symbol = SimpleMarkerSymbol(style: .circle, color: AppTheme.accentUIColor, size: 12)
                let renderer = SimpleRenderer(symbol: symbol)
                layer.featureReduction = ClusteringFeatureReduction(renderer: renderer)
            }
            featureLayer = layer
            isLoaded = true
        } catch {
            loadError = error
            isLoaded = false
        }
    }

    /// Add a track point with retry and exponential backoff.
    func addTrackPoint(_ point: TrackPoint) async {
        guard let table = featureTable, let geodatabase = serviceGeodatabase else {
            lastSyncError = TrackFeatureServiceError.notLoaded
            return
        }
        lastSyncError = nil
        let geometry = Point(
            x: point.longitude,
            y: point.latitude,
            spatialReference: .wgs84
        )
        let normalized = GeometryEngine.normalizeCentralMeridian(of: geometry) ?? geometry
        var attributes: [String: any Sendable] = [
            attributeMapping.deviceId: point.deviceID,
            attributeMapping.timestamp: ISO8601DateFormatter().string(from: point.timestamp),
            attributeMapping.speed: point.speed,
            attributeMapping.heading: point.heading
        ]
        if let sid = point.sessionId {
            attributes[attributeMapping.sessionId] = sid.uuidString
        }
        if let name = point.routeName, !name.isEmpty {
            attributes[attributeMapping.routeName] = name
        }
        let feature = table.makeFeature(attributes: attributes, geometry: normalized)
        var attempt = 0
        while attempt <= maxRetries {
            do {
                try await table.add(feature)
                if geodatabase.hasLocalEdits {
                    _ = try await geodatabase.applyEdits()
                    lastSyncTime = Date()
                    retryCount = 0
                    DiagnosticsManager.shared.recordSyncAttempt(success: true)
                    return
                }
                DiagnosticsManager.shared.recordSyncAttempt(success: true)
                return
            } catch {
                lastSyncError = error
                DiagnosticsManager.shared.recordSyncAttempt(success: false)
                DiagnosticsManager.shared.log(DiagnosticEntry(kind: .syncFailure, message: error.localizedDescription, details: "attempt \(attempt + 1)"))
                attempt += 1
                if attempt <= maxRetries {
                    let delay = baseBackoffSeconds * (1 << min(attempt, 4))
                    try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                }
            }
        }
    }
}

enum TrackFeatureServiceError: LocalizedError {
    case notLoaded
    case layerNotFound(Int)

    var errorDescription: String? {
        switch self {
        case .notLoaded: return String(localized: "Feature service not loaded.")
        case .layerNotFound(let id): return String(localized: "Layer ID \(id) not found.")
        }
    }
}
