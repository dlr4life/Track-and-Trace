//
//  BatteryMonitor.swift
//  T&T Run
//
//  Battery level and state for adaptive sync and power saver mode.
//

import Combine
import Foundation
import UIKit

@MainActor
final class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

    @Published private(set) var level: Float = 1
    @Published private(set) var state: UIDevice.BatteryState = .unknown

    var isLowBattery: Bool {
        state == .unplugged && level < 0.2
    }

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        update()
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in BatteryMonitor.shared.update() }
        }
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in BatteryMonitor.shared.update() }
        }
    }

    private func update() {
        level = UIDevice.current.batteryLevel
        if level < 0 { level = 1 }
        state = UIDevice.current.batteryState
    }
}
