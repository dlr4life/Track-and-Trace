//
//  TrackPoint.swift
//  T&T Run
//
//  Track data model for GPS points sent to ArcGIS Feature Services.
//  Aligns with INFO.md §6 (Track Logging Engine) and §4 (Data Modeling).
//

import Foundation
import CoreLocation

/// A single GPS track point: latitude, longitude, timestamp, speed, heading, device id.
/// Used for route logging and sending to ArcGIS Feature Services.
struct TrackPoint: Sendable, Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let speed: Double
    let heading: Double
    let accuracy: Double
    let deviceID: String
    /// Optional session/route ID for analytics (route naming).
    var sessionId: UUID?
    /// Optional route/session display name.
    var routeName: String?

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        timestamp: Date = Date(),
        speed: Double = 0,
        heading: Double = 0,
        accuracy: Double = 0,
        deviceID: String,
        sessionId: UUID? = nil,
        routeName: String? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.speed = speed
        self.heading = heading
        self.accuracy = accuracy
        self.deviceID = deviceID
        self.sessionId = sessionId
        self.routeName = routeName
    }

    /// Build from CoreLocation CLLocation and device identifier; optional session/route.
    static func from(
        _ location: CLLocation,
        deviceID: String,
        sessionId: UUID? = nil,
        routeName: String? = nil
    ) -> TrackPoint {
        TrackPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            speed: location.speed >= 0 ? location.speed : 0,
            heading: location.course >= 0 ? location.course : 0,
            accuracy: location.horizontalAccuracy,
            deviceID: deviceID,
            sessionId: sessionId,
            routeName: routeName
        )
    }
}
