//
//  OfflineQueueService.swift
//  T&T Run
//
//  Queues track points when offline; flushes to sync when connectivity returns.
//

import Combine
import Foundation

private let queueKey = "ttrun.offline.queue"
private let maxQueued = 5000

/// Persists track points when offline and exposes them for sync when online.
@MainActor
final class OfflineQueueService: ObservableObject {
    static let shared = OfflineQueueService()

    @Published private(set) var queuedCount: Int = 0

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        queuedCount = loadQueue().count
    }

    func enqueue(_ point: TrackPoint) {
        var queue = loadQueue()
        queue.append(point)
        if queue.count > maxQueued {
            queue.removeFirst(queue.count - maxQueued)
        }
        saveQueue(queue)
        queuedCount = queue.count
    }

    func dequeueBatch(maxCount: Int = 100) -> [TrackPoint] {
        var queue = loadQueue()
        let batch = Array(queue.prefix(maxCount))
        queue.removeFirst(min(batch.count, queue.count))
        saveQueue(queue)
        queuedCount = queue.count
        return batch
    }

    func clearQueue() {
        saveQueue([])
        queuedCount = 0
    }

    private func loadQueue() -> [TrackPoint] {
        guard let data = defaults.data(forKey: queueKey) else { return [] }
        return (try? decoder.decode([TrackPoint].self, from: data)) ?? []
    }

    private func saveQueue(_ queue: [TrackPoint]) {
        guard let data = try? encoder.encode(queue) else { return }
        defaults.set(data, forKey: queueKey)
    }
}
