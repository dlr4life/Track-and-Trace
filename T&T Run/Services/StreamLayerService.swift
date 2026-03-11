//
//  StreamLayerService.swift
//  T&T Run
//
//  Optional ArcGIS Stream Layer for very low-latency position updates.
//  When the backend supports GeoEvent/Stream Service, load the stream layer and add to map.
//

import Combine
import Foundation

/// When backend supports it, use a stream layer for real-time position updates.
/// Configure useStreamLayer in Settings; integrate with your ArcGIS Stream Layer type when available.
@MainActor
final class StreamLayerService: ObservableObject {
    @Published private(set) var loadError: Error?

    func load(streamServiceURL: URL) async {
        loadError = nil
        // TODO: Add ArcGIS Stream Layer when SDK provides the type (e.g. StreamLayer or similar).
        // For now this is a placeholder; enable "Use Stream Layer" in Settings for future use.
    }
}
