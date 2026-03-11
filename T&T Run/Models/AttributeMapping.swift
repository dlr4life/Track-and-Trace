//
//  AttributeMapping.swift
//  T&T Run
//
//  Maps app fields to Feature Service attribute names for custom schemas.
//

import Foundation

/// Default and customizable attribute names for Feature Service fields.
struct AttributeMapping: Codable, Sendable {
    var deviceId: String
    var timestamp: String
    var speed: String
    var heading: String
    var sessionId: String
    var routeName: String

    static let `default` = AttributeMapping(
        deviceId: "device_id",
        timestamp: "timestamp",
        speed: "speed",
        heading: "heading",
        sessionId: "session_id",
        routeName: "route_name"
    )
}
