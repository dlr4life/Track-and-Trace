//
//  FeatureServiceConfig.swift
//  T&T Run
//
//  Single Feature Service / layer configuration for multiple layers support.
//

import Foundation

/// One Feature Service layer configuration (URL + layer ID + optional label).
struct FeatureServiceConfig: Codable, Identifiable, Sendable {
    var id: UUID
    var label: String
    var serviceURL: String
    var layerID: Int

    init(id: UUID = UUID(), label: String, serviceURL: String, layerID: Int = 0) {
        self.id = id
        self.label = label
        self.serviceURL = serviceURL
        self.layerID = layerID
    }

    var resolvedURL: URL? {
        let t = serviceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return URL(string: t)
    }
}
