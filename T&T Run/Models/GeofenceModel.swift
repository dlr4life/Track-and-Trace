//
//  GeofenceModel.swift
//  T&T Run
//
//  Geofence definition for enter/exit alerts and actions.
//

import Foundation
import CoreLocation
import MapKit

/// Geofence: circular region with optional name and notify-on-enter/exit.
struct GeofenceModel: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var notifyOnEntry: Bool
    var notifyOnExit: Bool

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 100,
        notifyOnEntry: Bool = true,
        notifyOnExit: Bool = true
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.notifyOnEntry = notifyOnEntry
        self.notifyOnExit = notifyOnExit
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clRegion: CLCircularRegion {
        let region = CLCircularRegion(
            center: coordinate,
            radius: radiusMeters,
            identifier: id.uuidString
        )
        region.notifyOnEntry = notifyOnEntry
        region.notifyOnExit = notifyOnExit
        return region
    }
}
