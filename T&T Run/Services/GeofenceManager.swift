//
//  GeofenceManager.swift
//  T&T Run
//
//  Monitors geofences and triggers alerts on enter/exit.
//

import Combine
import CoreLocation
import Foundation
import UserNotifications

@MainActor
final class GeofenceManager: NSObject, ObservableObject {
    static let shared = GeofenceManager()

    @Published var geofences: [GeofenceModel] = []
    @Published var lastEvent: (GeofenceModel, EnterOrExit)?

    enum EnterOrExit { case enter, exit }

    private let locationManager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private let key = "ttrun.geofences"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = false
        load()
    }

    func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([GeofenceModel].self, from: data) else { return }
        geofences = decoded
        restartMonitoring()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(geofences) else { return }
        defaults.set(data, forKey: key)
        restartMonitoring()
    }

    func add(_ geofence: GeofenceModel) {
        geofences.append(geofence)
        save()
    }

    func remove(_ geofence: GeofenceModel) {
        geofences.removeAll { $0.id == geofence.id }
        locationManager.stopMonitoring(for: geofence.clRegion)
        save()
    }

    private func restartMonitoring() {
        for region in locationManager.monitoredRegions {
            if region is CLCircularRegion {
                locationManager.stopMonitoring(for: region)
            }
        }
        for g in geofences {
            let region = g.clRegion
            region.notifyOnEntry = g.notifyOnEntry
            region.notifyOnExit = g.notifyOnExit
            locationManager.startMonitoring(for: region)
        }
    }

    private func notifyUser(geofence: GeofenceModel, enter: Bool) {
        let content = UNMutableNotificationContent()
        content.title = enter ? String(localized: "Geofence entered") : String(localized: "Geofence left")
        content.body = geofence.name
        content.sound = .default
        let request = UNNotificationRequest(identifier: "geofence-\(geofence.id.uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension GeofenceManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circular = region as? CLCircularRegion else { return }
        Task { @MainActor in
            if let g = geofences.first(where: { $0.id.uuidString == circular.identifier }) {
                lastEvent = (g, .enter)
                notifyUser(geofence: g, enter: true)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circular = region as? CLCircularRegion else { return }
        Task { @MainActor in
            if let g = geofences.first(where: { $0.id.uuidString == circular.identifier }) {
                lastEvent = (g, .exit)
                notifyUser(geofence: g, enter: false)
            }
        }
    }
}
