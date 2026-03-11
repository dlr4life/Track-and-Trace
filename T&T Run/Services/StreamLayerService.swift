//
//  StreamLayerService.swift
//  T&T Run
//
//  Optional ArcGIS Stream Layer for very low-latency position updates.
//  When the backend supports GeoEvent/Stream Service, load the stream layer and add to map.
//

import ArcGIS
import Combine
import Foundation

/// When backend supports it, use a stream layer for real-time position updates.
/// Configure useStreamLayer and streamServiceURL in Settings.
@MainActor
final class StreamLayerService: ObservableObject {
    static let shared = StreamLayerService()

    @Published private(set) var loadError: Error?
    /// The stream layer to add to the map when useStreamLayer is true. Adding to map auto-loads the data source.
    @Published private(set) var streamLayer: Layer?

    private init() {}

    /// Loads the stream service and creates a DynamicEntityLayer. The layer will connect when added to the map.
    func load(streamServiceURL: URL) async {
        loadError = nil
        streamLayer = nil
        let streamService = ArcGISStreamService(url: streamServiceURL)
        let layer = DynamicEntityLayer(dataSource: streamService)
        streamLayer = layer
        // DynamicEntityLayer/data source load and connect when the layer is added to the map.
    }
}
