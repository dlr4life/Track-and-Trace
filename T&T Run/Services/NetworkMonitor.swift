//
//  NetworkMonitor.swift
//  T&T Run
//
//  Monitors network reachability for offline support and sync coordination.
//

import Combine
import Foundation
import Network

/// Monitors network connectivity; used to queue track points when offline and sync when online.
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var isExpensive = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.ttrun.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { path in
            let connected = path.status == .satisfied
            let expensive = path.isExpensive
            Task { @MainActor in
                NetworkMonitor.shared.isConnected = connected
                NetworkMonitor.shared.isExpensive = expensive
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
