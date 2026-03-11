//
//  TrackHistoryStore.swift
//  T&T Run
//
//  Rolling local history of track points for path polyline and export.
//

import Combine
import Foundation
import CoreLocation

private let historyKey = "ttrun.track.history"
private let maxPoints = 10000

/// Stores a rolling history of track points locally for path display and export.
@MainActor
final class TrackHistoryStore: ObservableObject {
    static let shared = TrackHistoryStore()

    @Published private(set) var points: [TrackPoint] = []

    private let fileManager = FileManager.default
    private var fileURL: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("track_history.json", isDirectory: false)
    }
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        load()
    }

    func append(_ point: TrackPoint) {
        points.append(point)
        if points.count > maxPoints {
            points.removeFirst(points.count - maxPoints)
        }
        save()
    }

    func clear() {
        points.removeAll()
        save()
    }

    /// Points for the current or given session (by sessionId); if nil, returns all.
    func pointsForSession(_ sessionId: UUID?) -> [TrackPoint] {
        guard let id = sessionId else { return points }
        return points.filter { $0.sessionId == id }
    }

    /// Ordered coordinates for polyline (current session or full history).
    func polylineCoordinates(sessionId: UUID? = nil) -> [CLLocationCoordinate2D] {
        let list = sessionId.map { pointsForSession($0) } ?? points
        return list.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private func load() {
        guard let url = fileURL, fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode([TrackPoint].self, from: data) else { return }
        points = decoded
    }

    private func save() {
        guard let url = fileURL, let data = try? encoder.encode(points) else { return }
        try? data.write(to: url)
    }
}
