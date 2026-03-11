//
//  DiagnosticsManager.swift
//  T&T Run
//
//  Last N errors and sync success rate for support and tuning.
//

import Combine
import Foundation

private let logKey = "ttrun.diagnostics.log"
private let maxEntries = 200
private let syncStatsKey = "ttrun.sync.stats"

@MainActor
final class DiagnosticsManager: ObservableObject {
    static let shared = DiagnosticsManager()

    @Published private(set) var entries: [DiagnosticEntry] = []
    @Published private(set) var syncAttempts: Int = 0
    @Published private(set) var syncSuccesses: Int = 0

    var syncSuccessRate: Double {
        guard syncAttempts > 0 else { return 1 }
        return Double(syncSuccesses) / Double(syncAttempts)
    }

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        load()
    }

    func log(_ entry: DiagnosticEntry) {
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        save()
    }

    func recordSyncAttempt(success: Bool) {
        syncAttempts += 1
        if success { syncSuccesses += 1 }
        defaults.set(syncAttempts, forKey: syncStatsKey + ".attempts")
        defaults.set(syncSuccesses, forKey: syncStatsKey + ".successes")
    }

    func reset() {
        entries.removeAll()
        syncAttempts = 0
        syncSuccesses = 0
        defaults.removeObject(forKey: logKey)
        defaults.removeObject(forKey: syncStatsKey + ".attempts")
        defaults.removeObject(forKey: syncStatsKey + ".successes")
    }

    func exportLog() -> String {
        let lines = entries.map { e in
            "\(e.timestamp.ISO8601Format()) [\(e.kind.rawValue)] \(e.message)" + (e.details.map { " | \($0)" } ?? "")
        }
        return lines.joined(separator: "\n")
    }

    private func load() {
        if let data = defaults.data(forKey: logKey),
           let decoded = try? decoder.decode([DiagnosticEntry].self, from: data) {
            entries = decoded
        }
        syncAttempts = defaults.integer(forKey: syncStatsKey + ".attempts")
        syncSuccesses = defaults.integer(forKey: syncStatsKey + ".successes")
    }

    private func save() {
        guard let data = try? encoder.encode(entries) else { return }
        defaults.set(data, forKey: logKey)
    }
}
