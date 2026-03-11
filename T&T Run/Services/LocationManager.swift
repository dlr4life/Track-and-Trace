//
//  LocationManager.swift
//  T&T Run
//
//  Captures GPS; supports background (significant-change) and battery-conscious accuracy.
//

import Combine
import CoreLocation
import Foundation
import UIKit

/// Manages device location: authorization, updates, and publishing last location for map + feature service.
/// Supports significant-change mode in background to avoid platform assertions; optional reduced accuracy for power saver.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isUpdating = false

    private let manager = CLLocationManager()
    var deviceID: String { UIDevice.current.identifierForVendor?.uuidString ?? "device" }

    /// When true, use significant-change only (background-friendly); when false, use standard location updates.
    var useSignificantChangeOnly = false
    /// When true, use reduced accuracy (e.g. hundred meters) for power saver.
    var useReducedAccuracy = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.allowsBackgroundLocationUpdates = false
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func startUpdatingLocation() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        if useSignificantChangeOnly {
            manager.startMonitoringSignificantLocationChanges()
            manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            manager.distanceFilter = CLLocationDistanceMax
        } else {
            manager.desiredAccuracy = useReducedAccuracy ? kCLLocationAccuracyHundredMeters : kCLLocationAccuracyBest
            manager.distanceFilter = useReducedAccuracy ? 50 : 5
            manager.startUpdatingLocation()
        }
        manager.startUpdatingHeading()
        isUpdating = true
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopUpdatingHeading()
        isUpdating = false
    }

    /// Call when app enters background: switch to significant-change to keep tracking without high-accuracy drain.
    func setBackgroundMode(_ inBackground: Bool) {
        useSignificantChangeOnly = inBackground
        if isUpdating {
            startUpdatingLocation()
        }
    }

    /// Update accuracy based on power saver or low battery.
    func setReducedAccuracy(_ reduced: Bool) {
        useReducedAccuracy = reduced
        if isUpdating && !useSignificantChangeOnly {
            manager.desiredAccuracy = reduced ? kCLLocationAccuracyHundredMeters : kCLLocationAccuracyBest
            manager.distanceFilter = reduced ? 50 : 5
        }
    }

    func currentTrackPoint(sessionId: UUID? = nil, routeName: String? = nil) -> TrackPoint? {
        guard let loc = lastLocation else { return nil }
        return TrackPoint.from(loc, deviceID: deviceID, sessionId: sessionId, routeName: routeName)
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = location
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
