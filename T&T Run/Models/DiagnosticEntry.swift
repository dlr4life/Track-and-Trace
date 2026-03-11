//
//  DiagnosticEntry.swift
//  T&T Run
//
//  Single diagnostic log entry for health and support.
//

import Foundation

struct DiagnosticEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let kind: Kind
    let message: String
    let details: String?

    enum Kind: String, Codable, CaseIterable {
        case syncSuccess
        case syncFailure
        case loadError
        case locationError
        case geofence
        case auth
        case network
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), kind: Kind, message: String, details: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.message = message
        self.details = details
    }
}
