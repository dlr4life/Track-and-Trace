//
//  TrackMapView.swift
//  T&T Run
//
//  Map, device location, feature layers (with clustering), track polyline, offline queue, sync.
//

import ArcGIS
import Combine
import CoreLocation
import SwiftUI

private var isRunningInPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
}

// MARK: - View

struct TrackMapView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var locationManager: LocationManager
    @StateObject private var viewModel: TrackMapViewModel
    @Environment(\.scenePhase) private var scenePhase
    /// When set, a settings button is shown in the overlay; call to open Settings.
    var onOpenSettings: (() -> Void)?

    init(settings: AppSettings, locationManager: LocationManager, onOpenSettings: (() -> Void)? = nil) {
        self.settings = settings
        self.locationManager = locationManager
        self.onOpenSettings = onOpenSettings
        _viewModel = StateObject(wrappedValue: TrackMapViewModel(settings: settings, locationManager: locationManager))
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapContent
                .ignoresSafeArea(.container)
            statusOverlay
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppCopy.accMapView)
        .task {
            await viewModel.setup()
        }
        .onDisappear {
            viewModel.stopTracking()
        }
        .onChange(of: settings.basemapStyle) { _, _ in
            viewModel.updateBasemap(settings.basemapStyle.arcGISStyle)
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.setScenePhase(newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .trackingPausedDidChange)) { _ in
            viewModel.refreshPausedState()
        }
    }

    private var mapContent: some View {
        MapView(map: viewModel.map, graphicsOverlays: [viewModel.trackGraphicsOverlay])
            .locationDisplay(viewModel.locationDisplay)
            .overlay(alignment: .top) {
                if let error = viewModel.loadError {
                    errorBanner(error.localizedDescription, title: AppCopy.loadErrorTitle)
                }
            }
    }

    private var statusOverlay: some View {
        VStack(spacing: 0) {
            if let error = viewModel.lastSyncError {
                errorBanner(error.localizedDescription, title: AppCopy.syncErrorTitle)
            }
            if viewModel.repeatedSyncFailure {
                Text(String(localized: "Sync repeatedly failing. Check network and settings."))
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.errorColor)
                    .padding(.horizontal)
            }
            statusBar
        }
        .padding(.horizontal, AppTheme.padding)
        .padding(.top, AppTheme.padding)
    }

    private var statusBar: some View {
        HStack(spacing: AppTheme.paddingCompact) {
            Image(systemName: settings.trackingPaused ? "pause.circle" : (viewModel.isTracking ? "location.fill" : "location.slash"))
                .foregroundStyle(settings.trackingPaused ? AppTheme.warningColor : (viewModel.isTracking ? AppTheme.successColor : Color.secondary))
            Text(settings.trackingPaused ? String(localized: "Tracking paused") : (viewModel.isTracking ? String(localized: "Tracking on") : String(localized: "Tracking off")))
                .font(AppTheme.caption)
            Spacer()
            if OfflineQueueService.shared.queuedCount > 0 {
                Text(String(localized: "\(OfflineQueueService.shared.queuedCount) queued"))
                    .font(AppTheme.caption)
                    .foregroundStyle(.secondary)
            }
            Text(lastSyncText)
                .font(AppTheme.caption)
                .foregroundStyle(.secondary)
            if let onOpenSettings {
                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.body)
                        .frame(minWidth: AppTheme.minTouchTarget, minHeight: AppTheme.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(AppCopy.accSettingsButton)
            }
        }
        .padding(AppTheme.paddingCompact)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusButton))
        .padding(.top, AppTheme.paddingCompact)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityStatusLabel)
    }

    private var lastSyncText: String {
        if let date = viewModel.lastSyncTime {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return AppCopy.lastSyncNever
    }

    private var accessibilityStatusLabel: String {
        var parts: [String] = []
        parts.append(settings.trackingPaused ? String(localized: "Tracking paused") : (viewModel.isTracking ? String(localized: "Tracking on") : String(localized: "Tracking off")))
        parts.append(String(localized: "Last sync: \(lastSyncText)"))
        if OfflineQueueService.shared.queuedCount > 0 {
            parts.append(String(localized: "\(OfflineQueueService.shared.queuedCount) points queued"))
        }
        return parts.joined(separator: ". ")
    }

    private func errorBanner(_ message: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.errorColor)
            Text(message)
                .font(AppTheme.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.paddingCompact)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusButton))
        .padding(.horizontal)
        .padding(.bottom, AppTheme.paddingCompact)
    }
}

// MARK: - View model

@MainActor
final class TrackMapViewModel: ObservableObject {
    private let settings: AppSettings
    private let locationManager: LocationManager

    private(set) lazy var map: Map = Map(basemapStyle: settings.basemapStyle.arcGISStyle)
    let locationDisplay = LocationDisplay(dataSource: SystemLocationDataSource())

    @Published var loadError: Error?
    @Published var lastSyncError: Error?
    @Published var lastSyncTime: Date?
    @Published private(set) var isTracking = false
    @Published var repeatedSyncFailure = false

    private var trackFeatureServices: [TrackFeatureService] = []
    let trackGraphicsOverlay = GraphicsOverlay()
    private var syncTask: Task<Void, Never>?
    private var flushTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var consecutiveFailures = 0
    private let failureThresholdForWarning = 3

    init(settings: AppSettings, locationManager: LocationManager) {
        self.settings = settings
        self.locationManager = locationManager
    }

    func updateBasemap(_ style: ArcGIS.Basemap.Style) {
        map.basemap = Basemap(style: style)
    }

    /// When settings.offlineBasemapPath points to a .tpk or .vtpk file, use it as the basemap.
    private func applyOfflineBasemapIfNeeded() {
        let path = settings.offlineBasemapPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        let fileURL: URL
        if path.hasPrefix("/") || path.contains("://") {
            guard let url = URL(string: path.hasPrefix("/") ? "file://" + path : path) else { return }
            fileURL = url
        } else {
            guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(path) else { return }
            fileURL = url
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let ext = fileURL.pathExtension.lowercased()
        if ext == "tpk" || ext == "tpkx" {
            let cache = TileCache(fileURL: fileURL)
            let layer = ArcGISTiledLayer(tileCache: cache)
            map.basemap = Basemap(baseLayer: layer)
        }
        // .vtpk (vector tile package): use ArcGISVectorTiledLayer when your SDK version supports it.
    }

    func setScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            locationManager.setBackgroundMode(true)
        case .active, .inactive:
            locationManager.setBackgroundMode(false)
        @unknown default:
            break
        }
    }

    func refreshPausedState() {
        if settings.trackingPaused {
            // No need to stop location; we just don't record or sync.
        }
    }

    func setup() async {
        if isRunningInPreview { return }

        applyOfflineBasemapIfNeeded()

        let manager = CLLocationManager()
        if manager.authorizationStatus == .notDetermined {
            locationManager.requestAuthorization()
        }

        locationManager.setReducedAccuracy(settings.powerSaverMode || BatteryMonitor.shared.isLowBattery)

        do {
            try await locationDisplay.dataSource.start()
            locationDisplay.initialZoomScale = 40_000
            locationDisplay.autoPanMode = .recenter
        } catch {
            loadError = error
            DiagnosticsManager.shared.log(DiagnosticEntry(kind: .loadError, message: error.localizedDescription))
        }

        startTrackPolylineObserver()

        if settings.useStreamLayer, let streamURL = settings.resolvedStreamServiceURL {
            await StreamLayerService.shared.load(streamServiceURL: streamURL)
            if let layer = StreamLayerService.shared.streamLayer {
                map.addOperationalLayer(layer)
            }
        }

        locationManager.startUpdatingLocation()
        isTracking = true
        updateWidgetState()

        let configs = settings.activeFeatureServiceConfigs
        for config in configs {
            guard let url = config.resolvedURL else { continue }
            let service = TrackFeatureService(
                serviceURL: url,
                layerID: config.layerID,
                attributeMapping: settings.attributeMapping
            )
            await service.load(enableClustering: settings.useClustering)
            if let layer = service.featureLayer {
                map.addOperationalLayer(layer)
            }
            trackFeatureServices.append(service)
        }
        if let first = trackFeatureServices.first {
            observeSyncState(first)
        }
        startPeriodicSync()
        observeNetworkForFlush()
    }

    func stopTracking() {
        syncTask?.cancel()
        syncTask = nil
        flushTask?.cancel()
        flushTask = nil
        locationManager.stopUpdatingLocation()
        isTracking = false
        updateWidgetState()
    }

    private func startTrackPolylineObserver() {
        TrackHistoryStore.shared.$points
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTrackPolyline()
            }
            .store(in: &cancellables)
    }

    private func updateTrackPolyline() {
        let coords = TrackHistoryStore.shared.polylineCoordinates(sessionId: settings.currentSessionId)
        trackGraphicsOverlay.removeAllGraphics()
        guard coords.count >= 2 else { return }
        let points = coords.map { Point(x: $0.longitude, y: $0.latitude, spatialReference: .wgs84) }
        let polyline = Polyline(points: points)
        let symbol = SimpleLineSymbol(style: .solid, color: AppTheme.trackLineUIColor, width: AppTheme.trackLineWidth)
        trackGraphicsOverlay.addGraphic(Graphic(geometry: polyline, symbol: symbol))
    }

    private func observeSyncState(_ service: TrackFeatureService) {
        service.$lastSyncError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] err in
                self?.lastSyncError = err
                if err != nil {
                    self?.consecutiveFailures += 1
                    self?.repeatedSyncFailure = (self?.consecutiveFailures ?? 0) >= (self?.failureThresholdForWarning ?? 3)
                } else {
                    self?.consecutiveFailures = 0
                    self?.repeatedSyncFailure = false
                }
            }
            .store(in: &cancellables)
        service.$lastSyncTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.lastSyncTime = time
                WidgetStateManager.update(isTracking: self?.isTracking ?? false, lastSyncTime: time)
            }
            .store(in: &cancellables)
    }

    private func updateWidgetState() {
        WidgetStateManager.update(isTracking: isTracking, lastSyncTime: lastSyncTime)
    }

    private func startPeriodicSync() {
        syncTask = Task { [weak self] in
            while !Task.isCancelled, let self = self {
                let interval = UInt64(max(10, self.settings.effectiveSyncIntervalSeconds)) * 1_000_000_000
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled else { break }
                if self.settings.trackingPaused { continue }
                let sessionId = self.settings.currentSessionId
                let routeName = self.settings.currentRouteName.isEmpty ? nil : self.settings.currentRouteName
                guard let point = self.locationManager.currentTrackPoint(sessionId: sessionId, routeName: routeName) else { continue }
                TrackHistoryStore.shared.append(point)
                if NetworkMonitor.shared.isConnected {
                    for service in self.trackFeatureServices {
                        await service.addTrackPoint(point)
                    }
                } else {
                    OfflineQueueService.shared.enqueue(point)
                }
            }
        }
    }

    private func observeNetworkForFlush() {
        NetworkMonitor.shared.$isConnected
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.flushOfflineQueue()
            }
            .store(in: &cancellables)
    }

    private func flushOfflineQueue() {
        guard !trackFeatureServices.isEmpty else { return }
        flushTask = Task { [weak self] in
            guard let self = self else { return }
            while OfflineQueueService.shared.queuedCount > 0 {
                let batch = OfflineQueueService.shared.dequeueBatch(maxCount: 50)
                for point in batch {
                    for service in self.trackFeatureServices {
                        await service.addTrackPoint(point)
                    }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TrackMapView(settings: AppSettings.shared, locationManager: LocationManager())
}
