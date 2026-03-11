//
//  SettingsView.swift
//  T&T Run
//
//  Settings: feature service(s), sync, map, theme, privacy, geofences, diagnostics, export.
//

import SwiftUI

private enum SettingsSheetItem: Identifiable {
    case privacyNotice
    case attributeMapping
    case geofenceEditor
    case diagnostics
    case export
    var id: Self { self }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var geofenceManager = GeofenceManager.shared
    @State private var presentedSheet: SettingsSheetItem?
    @State private var showClearDataAlert = false
    @State private var showResetOnboardingAlert = false
    @State private var showOnboardingResetConfirmation = false
    @State private var exportFormat: ExportFormat = .gpx
    @State private var exportedURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                featureServiceSection
                syncSection
                mapSection
                portalSection
                themeSection
                onboardingSection
                powerSaverSection
                routeSessionSection
                privacySection
                geofenceSection
                dataSection
                aboutSection
            }
            .navigationTitle(AppCopy.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                applyOAuthConfig()
                authManager.updateSignInState()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppCopy.doneButton) { dismiss() }
                }
            }
            .sheet(item: $presentedSheet) { item in
                switch item {
                case .privacyNotice:
                    privacyNoticeView(onDismiss: { presentedSheet = nil })
                case .attributeMapping:
                    attributeMappingView(onDismiss: { presentedSheet = nil })
                case .geofenceEditor:
                    geofenceEditorView
                        .onDisappear { presentedSheet = nil }
                case .diagnostics:
                    NavigationStack {
                        DiagnosticsView()
                            .navigationTitle(String(localized: "Diagnostics"))
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(AppCopy.doneButton) { presentedSheet = nil }
                                }
                            }
                    }
                case .export:
                    exportSheet(onDismiss: { presentedSheet = nil })
                }
            }
            .alert(String(localized: "Clear local data?"), isPresented: $showClearDataAlert) {
                Button(AppCopy.cancelButton, role: .cancel) {}
                Button(AppCopy.clearButton, role: .destructive) {
                    clearAllLocalData()
                }
            } message: {
                Text(String(localized: "This will clear track history, offline queue, and diagnostics. Synced data is not affected."))
            }
            .alert(String(localized: "Reset onboarding?"), isPresented: $showResetOnboardingAlert) {
                Button(AppCopy.cancelButton, role: .cancel) {}
                Button(String(localized: "Reset"), role: .destructive) {
                    resetOnboarding()
                }
            } message: {
                Text(String(localized: "The onboarding tutorial will show again the next time you open the app."))
            }
            .alert(String(localized: "Onboarding reset"), isPresented: $showOnboardingResetConfirmation) {
                Button(AppCopy.doneButton, role: .cancel) {}
            } message: {
                Text(String(localized: "Onboarding has been reset. It will show on the next app restart."))
            }
        }
    }

    private var onboardingSection: some View {
        Section(String(localized: "Onboarding")) {
            Button(String(localized: "Reset onboarding")) {
                showResetOnboardingAlert = true
            }
            .accessibilityHint(String(localized: "Shows the tutorial again on next app launch"))
        }
    }

    private func resetOnboarding() {
        settings.resetOnboarding()
        showResetOnboardingAlert = false
        showOnboardingResetConfirmation = true
    }

    private var featureServiceSection: some View {
        Section {
            if settings.featureServiceConfigs.isEmpty {
                TextField(String(localized: "Feature Service URL"), text: $settings.featureServiceURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                HStack {
                    Text(String(localized: "Feature Layer ID"))
                    Spacer()
                    TextField("0", value: $settings.featureLayerID, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            }
            NavigationLink(destination: FeatureServiceConfigListView(settings: settings)) {
                Text(AppCopy.settingsManageLayers)
            }
        } header: {
            Text(String(localized: "Feature Service"))
        } footer: {
            Text(String(localized: "Leave URL empty to disable sync. Add multiple layers under Manage layers."))
        }
    }

    private var syncSection: some View {
        Section {
            HStack {
                Text(String(localized: "Sync interval (seconds)"))
                Spacer()
                Text("\(settings.syncIntervalSeconds) s")
                    .foregroundStyle(.secondary)
                Stepper("", value: $settings.syncIntervalSeconds, in: 10...300, step: 10)
                    .labelsHidden()
                    .accessibilityLabel("\(AppCopy.settingsSyncInterval), \(settings.syncIntervalSeconds) \(String(localized: "seconds"))")
                    .accessibilityValue("\(settings.syncIntervalSeconds)")
            }
            Toggle(String(localized: "Use clustering for many assets"), isOn: $settings.useClustering)
            Toggle(String(localized: "Use Stream Layer (low latency)"), isOn: $settings.useStreamLayer)
            if settings.useStreamLayer {
                TextField(String(localized: "Stream Service URL"), text: $settings.streamServiceURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "In power saver mode, effective interval is longer."))
                Text(AppCopy.settingsStreamLayerFooter)
                    .font(.caption)
            }
        }
    }

    private var mapSection: some View {
        Section {
            Picker(String(localized: "Map style"), selection: $settings.basemapStyle) {
                ForEach(AppBasemapStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.menu)
            TextField(AppCopy.settingsOfflineBasemapPath, text: $settings.offlineBasemapPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text(String(localized: "Map style"))
        } footer: {
            Text(AppCopy.settingsOfflineBasemapFooter)
        }
    }

    private var portalSection: some View {
        Section {
            TextField(AppCopy.settingsPortalURL, text: $settings.portalURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Toggle(AppCopy.settingsUseOAuth, isOn: $settings.useOAuth)
            if settings.useOAuth {
                TextField(String(localized: "OAuth Client ID"), text: $settings.oauthClientID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField(String(localized: "OAuth Redirect URL"), text: $settings.oauthRedirectURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            if authManager.isSignedIn, let user = authManager.portalUser {
                HStack {
                    Text(String(localized: "Signed in as"))
                    Spacer()
                    Text(user)
                        .foregroundStyle(.secondary)
                }
                Button(String(localized: "Sign out"), role: .destructive) {
                    authManager.signOut()
                }
            }
        } header: {
            Text(String(localized: "Portal & sign-in"))
        } footer: {
            Text(AppCopy.settingsPortalURLFooter)
        }
        .onChange(of: settings.portalURL) { _, _ in applyOAuthConfig() }
        .onChange(of: settings.useOAuth) { _, _ in applyOAuthConfig() }
        .onChange(of: settings.oauthClientID) { _, _ in applyOAuthConfig() }
        .onChange(of: settings.oauthRedirectURL) { _, _ in applyOAuthConfig() }
    }

    private func applyOAuthConfig() {
        guard settings.useOAuth else {
            AuthManager.shared.configureOAuth(portalURL: nil, clientID: nil, redirectURL: nil)
            return
        }
        AuthManager.shared.configureOAuth(
            portalURL: settings.resolvedPortalURL,
            clientID: settings.oauthClientID.isEmpty ? nil : settings.oauthClientID,
            redirectURL: settings.resolvedOauthRedirectURL
        )
    }

    private var themeSection: some View {
        Section(String(localized: "Appearance")) {
            Picker(String(localized: "Theme"), selection: $settings.appTheme) {
                ForEach(AppThemeOption.allCases) { opt in
                    Text(opt.displayName).tag(opt)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var powerSaverSection: some View {
        Section {
            Toggle(String(localized: "Power saver mode"), isOn: $settings.powerSaverMode)
        } footer: {
            Text(String(localized: "Longer sync interval and reduced location accuracy to save battery."))
        }
    }

    private var routeSessionSection: some View {
        Section {
            TextField(String(localized: "Route or run name"), text: $settings.currentRouteName)
                .textContentType(.name)
        } header: {
            Text(String(localized: "Route / session"))
        } footer: {
            Text(String(localized: "Optional. Synced points will be tagged with this name for analytics."))
        }
    }

    private var privacySection: some View {
        Section(String(localized: "Privacy")) {
            if !settings.privacyNoticeAccepted {
                Button(String(localized: "View privacy notice")) {
                    presentedSheet = .privacyNotice
                }
            }
            Toggle(String(localized: "Pause tracking"), isOn: $settings.trackingPaused)
            Button(String(localized: "Clear local data")) {
                showClearDataAlert = true
            }
        }
    }

    private var geofenceSection: some View {
        Section(String(localized: "Geofences")) {
            ForEach(geofenceManager.geofences) { g in
                HStack {
                    Text(g.name)
                    Spacer()
                    Text("\(Int(g.radiusMeters)) m")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text("\(g.name), \(Int(g.radiusMeters)) meters"))
            }
            .onDelete { indexSet in
                indexSet.sorted(by: >).forEach { i in
                    geofenceManager.remove(geofenceManager.geofences[i])
                }
            }
            Button(String(localized: "Add geofence")) {
                presentedSheet = .geofenceEditor
            }
            .accessibilityLabel(String(localized: "Add geofence"))
        }
    }

    private var dataSection: some View {
        Section(String(localized: "Data")) {
            Button(String(localized: "Attribute mapping")) {
                presentedSheet = .attributeMapping
            }
            Button(String(localized: "Export track")) {
                presentedSheet = .export
            }
            Button(String(localized: "Diagnostics")) {
                presentedSheet = .diagnostics
            }
        }
    }

    private var aboutSection: some View {
        Section(String(localized: "About")) {
            HStack {
                Text(AppCopy.settingsVersion)
                Spacer()
                Text(Bundle.main.appVersion)
                    .foregroundStyle(.secondary)
            }
            Text(AppCopy.settingsApiKeyNote)
                .font(AppTheme.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func privacyNoticeView(onDismiss: @escaping () -> Void) -> some View {
        NavigationStack {
            ScrollView {
                Text(privacyNoticeText)
                    .padding()
            }
            .navigationTitle(String(localized: "Privacy notice"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "I accept")) {
                        settings.privacyNoticeAccepted = true
                        onDismiss()
                    }
                }
            }
        }
    }

    private var privacyNoticeText: String {
        String(localized: "T&T Run uses your location to show your position on the map and, if you configure a Feature Service, to send track points to your organization’s ArcGIS service. Location is only sent to the URL you provide. You can pause tracking or clear local data at any time. We do not sell your data. For GDPR/CCPA: you have the right to access, correct, and delete your data; use in-app controls or contact your organization’s administrator.")
    }

    private func attributeMappingView(onDismiss: @escaping () -> Void) -> some View {
        NavigationStack {
            AttributeMappingView(mapping: $settings.attributeMapping)
                .navigationTitle(String(localized: "Attribute mapping"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppCopy.doneButton) { onDismiss() }
                    }
                }
        }
    }

    private var geofenceEditorView: some View {
        GeofenceEditorView(geofenceManager: geofenceManager)
    }

    private func exportSheet(onDismiss: @escaping () -> Void) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker(String(localized: "Format"), selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                let points = TrackHistoryStore.shared.points
                Text(String(localized: "\(points.count) points"))
                    .foregroundStyle(.secondary)
                Button(String(localized: "Export")) {
                    exportTrack()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle(String(localized: "Export track"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.cancelButton) { onDismiss() }
                }
            }
        }
    }

    private func exportTrack() {
        let points = TrackHistoryStore.shared.points
        let name = settings.currentRouteName.isEmpty ? AppCopy.exportDefaultTrackName : settings.currentRouteName
        let content: String
        switch exportFormat {
        case .gpx: content = ExportService.gpxString(from: points, trackName: name)
        case .geoJSON: content = ExportService.geoJSONString(from: points)
        }
        let ext = ExportService.fileExtension(for: exportFormat)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let fileName = "\(name)_\(formatter.string(from: Date())).\(ext)"
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = dir.appendingPathComponent(fileName)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        exportedURL = fileURL
        // Present share sheet
        if let url = exportedURL {
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = windowScene.windows.first?.rootViewController {
                root.present(av, animated: true)
            }
        }
    }

    private func clearAllLocalData() {
        TrackHistoryStore.shared.clear()
        OfflineQueueService.shared.clearQueue()
        DiagnosticsManager.shared.reset()
        showClearDataAlert = false
    }
}

// MARK: - Attribute mapping

struct AttributeMappingView: View {
    @Binding var mapping: AttributeMapping

    var body: some View {
        Form {
            TextField(String(localized: "Device ID field"), text: $mapping.deviceId)
            TextField(String(localized: "Timestamp field"), text: $mapping.timestamp)
            TextField(String(localized: "Speed field"), text: $mapping.speed)
            TextField(String(localized: "Heading field"), text: $mapping.heading)
            TextField(String(localized: "Session ID field"), text: $mapping.sessionId)
            TextField(String(localized: "Route name field"), text: $mapping.routeName)
        }
    }
}

// MARK: - Feature service config list

struct FeatureServiceConfigListView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        List {
            ForEach(settings.featureServiceConfigs) { config in
                NavigationLink(destination: FeatureServiceConfigEditView(config: binding(for: config))) {
                    HStack {
                        Text(config.label)
                        Spacer()
                        Text("\(AppCopy.settingsLayerIndexLabel) \(config.layerID)")
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("\(config.label), \(AppCopy.settingsLayerIndexLabel) \(config.layerID)")
            }
            .onDelete { indexSet in
                settings.featureServiceConfigs.remove(atOffsets: indexSet)
            }
            Button(String(localized: "Add layer")) {
                settings.featureServiceConfigs.append(FeatureServiceConfig(label: String(localized: "New layer"), serviceURL: "", layerID: 0))
            }
        }
        .navigationTitle(String(localized: "Feature layers"))
    }

    private func binding(for config: FeatureServiceConfig) -> Binding<FeatureServiceConfig> {
        guard let i = settings.featureServiceConfigs.firstIndex(where: { $0.id == config.id }) else {
            return .constant(config)
        }
        return Binding(
            get: { settings.featureServiceConfigs[i] },
            set: { settings.featureServiceConfigs[i] = $0 }
        )
    }
}

// MARK: - Feature service config editor

struct FeatureServiceConfigEditView: View {
    @Binding var config: FeatureServiceConfig

    var body: some View {
        Form {
            Section(String(localized: "Layer details")) {
                TextField(String(localized: "Label"), text: $config.label)
                    .textContentType(.name)
                TextField(String(localized: "Feature Service URL"), text: $config.serviceURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                HStack {
                    Text(String(localized: "Layer ID"))
                    Spacer()
                    TextField("0", value: $config.layerID, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            }
        }
        .navigationTitle(config.label.isEmpty ? String(localized: "Edit layer") : config.label)
    }
}

// MARK: - Geofence editor

struct GeofenceEditorView: View {
    @ObservedObject var geofenceManager: GeofenceManager
    @State private var name = ""
    @State private var lat = ""
    @State private var lon = ""
    @State private var radius: Double = 100
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "Name"), text: $name)
                TextField(String(localized: "Latitude"), text: $lat)
                    .keyboardType(.decimalPad)
                TextField(String(localized: "Longitude"), text: $lon)
                    .keyboardType(.decimalPad)
                HStack {
                    Text(String(localized: "Radius (m)"))
                    Slider(value: $radius, in: 50...1000, step: 50)
                    Text("\(Int(radius))")
                }
                Button(String(localized: "Add")) {
                    let latitude = Double(lat) ?? 0
                    let longitude = Double(lon) ?? 0
                    let g = GeofenceModel(name: name.isEmpty ? String(localized: "Geofence") : name, latitude: latitude, longitude: longitude, radiusMeters: radius)
                    geofenceManager.add(g)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
            .navigationTitle(String(localized: "Add geofence"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.cancelButton) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Diagnostics view

struct DiagnosticsView: View {
    @StateObject private var diag = DiagnosticsManager.shared

    var body: some View {
        List {
            Section(String(localized: "Sync stats")) {
                Text(String(localized: "Attempts: \(diag.syncAttempts)"))
                Text(String(localized: "Success rate: \(Int(diag.syncSuccessRate * 100))%"))
            }
            Section(String(localized: "Recent log")) {
                ForEach(diag.entries.prefix(50)) { e in
                    VStack(alignment: .leading) {
                        Text(e.message)
                            .font(.caption)
                        Text(e.timestamp.formatted())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Export")) {
                    let log = DiagnosticsManager.shared.exportLog()
                    UIPasteboard.general.string = log
                }
            }
        }
    }
}


private extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

#Preview {
    SettingsView(settings: AppSettings.shared)
}
