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

private enum ToolSheet: Identifiable {
    case geocode
    case route
    case buffer
    var id: Self { self }
}

struct TrackMapView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var locationManager: LocationManager
    @StateObject private var viewModel: TrackMapViewModel
    @Environment(\.scenePhase) private var scenePhase
    /// When set, a settings button is shown in the overlay; call to open Settings.
    var onOpenSettings: (() -> Void)?

    @State private var toolSheet: ToolSheet?
    @State private var geocodeAddress = ""
    @State private var routeFromAddress = ""
    @State private var routeToAddress = ""
    @State private var bufferDistance: Double = 1000
    @State private var zoomTrigger = 0

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
            toolsToolbar
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
        .sheet(item: $toolSheet) { sheet in
            toolSheetContent(sheet)
        }
        .alert(String(localized: "Tools Error"), isPresented: Binding(
            get: { viewModel.toolsError != nil },
            set: { if !$0 { viewModel.toolsError = nil } }
        )) {
            Button(String(localized: "OK"), role: .cancel) { viewModel.toolsError = nil }
        } message: {
            if let msg = viewModel.toolsError { Text(msg) }
        }
    }

    private var mapContent: some View {
        MapViewReader { mapViewProxy in
            MapView(map: viewModel.map, graphicsOverlays: [viewModel.trackGraphicsOverlay, viewModel.toolsGraphicsOverlay])
                .locationDisplay(viewModel.locationDisplay)
                .overlay(alignment: .top) {
                    if let error = viewModel.loadError {
                        errorBanner(error.localizedDescription, title: AppCopy.loadErrorTitle)
                    }
                }
                .task(id: zoomTrigger) {
                    guard zoomTrigger > 0, let geom = viewModel.pendingZoomGeometry else { return }
                    await mapViewProxy.setViewpointGeometry(geom, padding: 80)
                    viewModel.pendingZoomGeometry = nil
                }
        }
    }

    private var toolsToolbar: some View {
        VStack {
            Spacer()
            HStack(spacing: AppTheme.paddingCompact) {
                Button {
                    if let point = viewModel.locateMePoint() {
                        viewModel.pendingZoomGeometry = point
                        zoomTrigger += 1
                    }
                } label: {
                    Text(String(localized: "Location"))
                        .font(AppTheme.caption)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(String(localized: "Locate me"))

                Button {
                    toolSheet = .geocode
                } label: {
                    Text(String(localized: "Geocode"))
                        .font(AppTheme.caption)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(String(localized: "Geocode address"))

                Button {
                    toolSheet = .route
                } label: {
                    Text(String(localized: "Route"))
                        .font(AppTheme.caption)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(String(localized: "Find route"))

                Button {
                    toolSheet = .buffer
                } label: {
                    Text(String(localized: "Buffer"))
                        .font(AppTheme.caption)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(String(localized: "Create buffer"))
            }
            .padding(AppTheme.paddingCompact)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusButton))
            .padding(.horizontal, AppTheme.padding)
            .padding(.bottom, AppTheme.padding)
        }
    }

    @ViewBuilder
    private func toolSheetContent(_ sheet: ToolSheet) -> some View {
        switch sheet {
        case .geocode:
            GeocodeSheetView(
                address: $geocodeAddress,
                suggest: { await viewModel.suggestAddresses(searchText: $0) },
                onSearch: {
                    toolSheet = nil
                    Task {
                        _ = await viewModel.doGeocode(address: geocodeAddress)
                        zoomTrigger += 1
                    }
                },
                onCancel: { toolSheet = nil }
            )
        case .route:
            RouteSheetView(
                fromAddress: $routeFromAddress,
                toAddress: $routeToAddress,
                suggest: { await viewModel.suggestAddresses(searchText: $0) },
                onSolve: {
                    toolSheet = nil
                    Task {
                        let origin: Point?
                        if routeFromAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            origin = viewModel.locateMePoint()
                        } else {
                            origin = await viewModel.geocodePoint(address: routeFromAddress)
                        }
                        guard let o = origin else { return }
                        guard let d = await viewModel.geocodePoint(address: routeToAddress) else { return }
                        _ = await viewModel.doRoute(origin: o, destination: d)
                        zoomTrigger += 1
                    }
                },
                onCancel: { toolSheet = nil }
            )
        case .buffer:
            BufferSheetView(
                distance: $bufferDistance,
                onApply: {
                    toolSheet = nil
                    guard let c = viewModel.locateMePoint() else { return }
                    _ = viewModel.doBuffer(center: c, distanceMeters: bufferDistance)
                    zoomTrigger += 1
                },
                onCancel: { toolSheet = nil }
            )
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
    /// Overlay for geocode marker, route line, and buffer polygon.
    let toolsGraphicsOverlay = GraphicsOverlay()

    @Published var loadError: Error?
    @Published var toolsError: String?
    /// When set, the map view should zoom to this geometry (used after geocode/route/buffer).
    @Published var pendingZoomGeometry: Geometry?
    @Published var lastSyncError: Error?
    @Published var lastSyncTime: Date?
    @Published private(set) var isTracking = false
    @Published var repeatedSyncFailure = false

    private var trackFeatureServices: [TrackFeatureService] = []
    let trackGraphicsOverlay = GraphicsOverlay()
    private let locatorTask = LocatorTask(url: URL(string: "https://geocode-api.arcgis.com/arcgis/rest/services/World/GeocodeServer")!)
    private let routeTask = RouteTask(url: URL(string: "https://route-api.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World")!)
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

    // MARK: - Map tools (Locate, Geocode, Route, Buffer)

    /// Returns current device location as a WGS84 point for centering the map (locateMe).
    func locateMePoint() -> Point? {
        guard let loc = locationManager.lastLocation else { return nil }
        return Point(x: loc.coordinate.longitude, y: loc.coordinate.latitude, spatialReference: .wgs84)
    }

    /// Fetch address/place suggestions for predictive text (autocomplete).
    func suggestAddresses(searchText: String, maxResults: Int = 8) async -> [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        do {
            let params = SuggestParameters()
            params.maxResults = maxResults
            if let location = locationManager.lastLocation {
                params.preferredSearchLocation = Point(
                    x: location.coordinate.longitude,
                    y: location.coordinate.latitude,
                    spatialReference: .wgs84
                )
            }
            let results = try await locatorTask.suggest(forSearchText: query, parameters: params)
            return results.map(\.label)
        } catch {
            return []
        }
    }

    /// Geocode an address without adding graphics (e.g. for route endpoints).
    func geocodePoint(address: String) async -> Point? {
        do {
            let results = try await locatorTask.geocode(forSearchText: address)
            return results.first?.displayLocation
        } catch {
            toolsError = error.localizedDescription
            return nil
        }
    }

    /// Geocode an address, add a marker graphic, and return the result point for zooming.
    func doGeocode(address: String) async -> Point? {
        toolsError = nil
        toolsGraphicsOverlay.removeAllGraphics()
        do {
            let results = try await locatorTask.geocode(forSearchText: address)
            guard let first = results.first, let point = first.displayLocation else { return nil }
            let symbol = SimpleMarkerSymbol(style: .circle, color: AppTheme.accentUIColor, size: 24)
            toolsGraphicsOverlay.addGraphic(Graphic(geometry: point, symbol: symbol))
            pendingZoomGeometry = point
            return point
        } catch {
            toolsError = error.localizedDescription
            return nil
        }
    }

    /// Solve route between two points, add route graphic, return route geometry for zooming.
    func doRoute(origin: Point, destination: Point) async -> Geometry? {
        toolsError = nil
        toolsGraphicsOverlay.removeAllGraphics()
        do {
            let params = try await routeTask.makeDefaultParameters()
            params.setStops([Stop(point: origin), Stop(point: destination)])
            let result = try await routeTask.solveRoute(using: params)
            guard let route = result.routes.first, let polyline = route.geometry else { return nil }
            let symbol = SimpleLineSymbol(style: .solid, color: .systemBlue, width: 4)
            toolsGraphicsOverlay.addGraphic(Graphic(geometry: polyline, symbol: symbol))
            pendingZoomGeometry = polyline
            return polyline
        } catch {
            toolsError = error.localizedDescription
            return nil
        }
    }

    /// Create a buffer around a point and add polygon graphic. Returns the buffer polygon for zooming.
    func doBuffer(center: Point, distanceMeters: Double) -> Polygon? {
        toolsError = nil
        toolsGraphicsOverlay.removeAllGraphics()
        let distance = max(10, min(161_000, distanceMeters)) // 10 m up to 100 miles
        let buffers = GeometryEngine.buffer(around: [center], distances: [distance], shouldUnion: false)
        guard let buffer = buffers.first else { return nil }
        let symbol = SimpleFillSymbol(style: .solid, color: UIColor.systemBlue.withAlphaComponent(0.25), outline: SimpleLineSymbol(style: .solid, color: .systemBlue, width: 2))
        toolsGraphicsOverlay.addGraphic(Graphic(geometry: buffer, symbol: symbol))
        pendingZoomGeometry = buffer
        return buffer
    }
}

// MARK: - Address field with predictive suggestions

private struct AddressSuggestField: View {
    @Binding var text: String
    var placeholder: String
    var suggest: (String) async -> [String]

    @State private var suggestions: [String] = []
    @State private var isSuggesting = false
    @State private var debounceTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private let debounceInterval: Duration = .milliseconds(300)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $text)
                .textContentType(.addressCity)
                .autocorrectionDisabled(false)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(for: debounceInterval)
                        guard !Task.isCancelled else { return }
                        isSuggesting = true
                        let results = await suggest(newValue)
                        guard !Task.isCancelled else { return }
                        suggestions = results
                        isSuggesting = false
                    }
                }
                .onTapGesture {
                    if !suggestions.isEmpty { return }
                    if text.count >= 2 {
                        Task {
                            isSuggesting = true
                            suggestions = await suggest(text)
                            isSuggesting = false
                        }
                    }
                }

            if isSuggesting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(String(localized: "Searching…"))
                        .font(AppTheme.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, AppTheme.paddingCompact)
            }

            if !suggestions.isEmpty && isFocused {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            text = suggestion
                            suggestions = []
                            isFocused = false
                        } label: {
                            Text(suggestion)
                                .font(AppTheme.caption)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, AppTheme.paddingCompact)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusButton))
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { suggestions = [] }
        }
    }
}

// MARK: - Tool sheets

private struct GeocodeSheetView: View {
    @Binding var address: String
    let suggest: (String) async -> [String]
    let onSearch: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AddressSuggestField(
                        text: $address,
                        placeholder: String(localized: "Address or place"),
                        suggest: suggest
                    )
                }
            }
            .navigationTitle(String(localized: "Geocode"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Search")) {
                        onSearch()
                    }
                    .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct RouteSheetView: View {
    @Binding var fromAddress: String
    @Binding var toAddress: String
    let suggest: (String) async -> [String]
    let onSolve: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AddressSuggestField(
                        text: $fromAddress,
                        placeholder: String(localized: "From (or leave blank for current location)"),
                        suggest: suggest
                    )
                }
                Section {
                    AddressSuggestField(
                        text: $toAddress,
                        placeholder: String(localized: "To address"),
                        suggest: suggest
                    )
                }
            }
            .navigationTitle(String(localized: "Route"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Solve")) { onSolve() }
                        .disabled(toAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct BufferSheetView: View {
    @Binding var distance: Double
    let onApply: () -> Void
    let onCancel: () -> Void

    private static let minMeters: Double = 10
    private static let maxMeters: Double = 161_000 // 100 miles

    @State private var distanceText: String = ""
    @FocusState private var distanceFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(String(localized: "Distance"))
                        TextField(String(localized: "Meters or miles"), text: $distanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($distanceFieldFocused)
                            .onSubmit { commitDistanceText() }
                            .onChange(of: distanceText) { _, _ in
                                if let v = parseDistance(distanceText) {
                                    distance = min(Self.maxMeters, max(Self.minMeters, v))
                                }
                            }
                    }
                    .onAppear {
                        distanceText = formatDistance(distance)
                    }
                    .onChange(of: distance) { _, newValue in
                        if !distanceFieldFocused {
                            distanceText = formatDistance(newValue)
                        }
                    }

                    Slider(
                        value: $distance,
                        in: Self.minMeters...Self.maxMeters,
                        step: 50
                    )
                    .onChange(of: distance) { _, newValue in
                        distanceText = formatDistance(newValue)
                    }

                    HStack {
                        Text(String(localized: "Range: 10 m – 100 mi"))
                            .font(AppTheme.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(milesDescription(distance))
                            .font(AppTheme.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(String(localized: "Buffer will be created around your current location. Enter a number (meters) or e.g. \"2 mi\" for miles."))
                    .font(AppTheme.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(String(localized: "Buffer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Apply"), action: onApply)
                }
            }
            .onDisappear {
                commitDistanceText()
            }
        }
    }

    private func commitDistanceText() {
        if let v = parseDistance(distanceText) {
            distance = min(Self.maxMeters, max(Self.minMeters, v))
        }
        distanceText = formatDistance(distance)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            let miles = meters / 1609.34
            return String(format: "%.2f mi", miles)
        }
        return String(format: "%.0f", meters)
    }

    private func milesDescription(_ meters: Double) -> String {
        let miles = meters / 1609.34
        return String(format: "≈ %.2f mi", miles)
    }

    /// Parse "500", "1.5 mi", "2 mi" etc. into meters.
    private func parseDistance(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty { return nil }
        let noMi = trimmed.replacingOccurrences(of: "mi", with: "").trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("mi"), let miles = Double(noMi), miles >= 0 {
            return miles * 1609.34
        }
        return Double(trimmed.replacingOccurrences(of: ",", with: ""))
    }

}

// MARK: - Preview

#Preview {
    TrackMapView(settings: AppSettings.shared, locationManager: LocationManager())
}
