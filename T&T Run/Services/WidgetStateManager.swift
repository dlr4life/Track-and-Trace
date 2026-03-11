//
//  WidgetStateManager.swift
//  T&T Run
//
//  Writes tracking state to App Group for Lock Screen / Home Screen widget.
//

import Foundation

enum WidgetStateManager {
    static let appGroupID = "group.com.minutelongsolutions.T-T-Run"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func update(isTracking: Bool, lastSyncTime: Date?) {
        sharedDefaults?.set(isTracking, forKey: "isTracking")
        sharedDefaults?.set(lastSyncTime, forKey: "lastSyncTime")
        sharedDefaults?.synchronize()
    }
}
