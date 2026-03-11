//
//  AppCopy.swift
//  T&T Run
//
//  Centralized labels, buttons, and messages for consistency and future localization.
//

import Foundation

enum AppCopy {
    // MARK: - App & navigation
    static let appName = "T&T Run"
    static let mapTitle = "Map"
    static let settingsTitle = "Settings"
    static let doneButton = "Done"
    static let saveButton = "Save"
    static let cancelButton = "Cancel"
    static let clearButton = "Clear"

    // MARK: - Settings
    static let settingsFeatureService = "Feature Service URL"
    static let settingsFeatureServicePlaceholder = "https://services.arcgis.com/…/FeatureServer"
    static let settingsFeatureServiceFooter = "Leave empty to disable syncing tracks to ArcGIS."
    static let settingsLayerID = "Feature Layer ID"
    static let settingsLayerIDFooter = "Layer index in the service (usually 0)."
    static let settingsSyncInterval = "Sync interval (seconds)"
    static let settingsSyncIntervalFooter = "How often to send location to the service (10–300)."
    static let settingsStreamLayerFooter = "Stream Layer requires backend support. Enable when your ArcGIS Stream Service is configured."
    static let settingsBasemap = "Map style"
    static let settingsAbout = "About"
    static let settingsVersion = "Version"
    static let settingsPortalURL = "Portal URL"
    static let settingsPortalURLPlaceholder = "https://yourorg.maps.arcgis.com"
    static let settingsPortalURLFooter = "Optional. For OAuth sign-in to secured services."
    static let settingsUseOAuth = "Use OAuth sign-in"
    static let settingsOfflineBasemapPath = "Offline basemap path"
    static let settingsOfflineBasemapFooter = "Path to a local .tpk or .vtpk when using offline maps."
    static let settingsManageLayers = "Manage layers"
    static let settingsLayerIndexLabel = "Layer"
    static let exportDefaultTrackName = "Track"
    static let settingsApiKeyNote = "Set the ArcGIS API key in the app’s scheme (ARCGIS_API_KEY) or in Info.plist."

    // MARK: - Map & tracking
    static let trackingStatusOn = "Tracking on"
    static let trackingStatusOff = "Tracking off"
    static let trackingPaused = "Tracking paused"
    static let lastSyncLabel = "Last sync"
    static let lastSyncNever = "Never"
    static let syncErrorTitle = "Sync error"
    static let loadErrorTitle = "Load error"
    static let locationErrorTitle = "Location error"
    static let pointsQueuedFormat = "%d queued"
    static let syncRepeatedFailureMessage = "Sync repeatedly failing. Check network and settings."

    // MARK: - Accessibility
    static let accSettingsButton = "Open settings"
    static let accMapView = "Track and trace map"
    static let accTrackingStatus = "Tracking status"
    static let accSyncIntervalValue = "Sync interval, %d seconds"
}
