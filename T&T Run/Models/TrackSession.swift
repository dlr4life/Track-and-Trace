//
//  TrackSession.swift
//  T&T Run
//
//  Named run/route for tagging synced points and analytics.
//

import Foundation

/// A named run or route; points synced during this session are tagged with sessionId.
struct TrackSession: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    let startedAt: Date
    var endedAt: Date?

    init(id: UUID = UUID(), name: String, startedAt: Date = Date(), endedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var isActive: Bool { endedAt == nil }
}
