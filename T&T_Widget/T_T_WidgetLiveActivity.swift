//
//  T_T_WidgetLiveActivity.swift
//  T&T_Widget
//
//  Live Activity: shows tracking status and last sync; opens app via ttrun://
//

import ActivityKit
import WidgetKit
import SwiftUI

struct T_T_WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isTracking: Bool
        var lastSync: Date
    }

    var name: String
}

struct T_T_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: T_T_WidgetAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: context.state.isTracking ? "location.fill" : "location.slash")
                    .foregroundStyle(context.state.isTracking ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.isTracking ? String(localized: "Tracking active") : String(localized: "Tracking off"))
                        .font(.subheadline.weight(.medium))
                    Text("\(String(localized: "Last sync")): \(context.state.lastSync.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isTracking ? "location.fill" : "location.slash")
                        .foregroundStyle(context.state.isTracking ? Color.green : Color.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.lastSync.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isTracking ? String(localized: "Tracking active") : String(localized: "Tracking off"))
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: context.state.isTracking ? "location.fill" : "location.slash")
                    .foregroundStyle(context.state.isTracking ? Color.green : Color.secondary)
            } compactTrailing: {
                Text(context.state.lastSync.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } minimal: {
                Image(systemName: context.state.isTracking ? "location.fill" : "location.slash")
                    .foregroundStyle(context.state.isTracking ? Color.green : Color.secondary)
            }
            .keylineTint(Color.accentColor)
            .widgetURL(URL(string: "ttrun://"))
        }
    }
}

extension T_T_WidgetAttributes {
    fileprivate static var preview: T_T_WidgetAttributes {
        T_T_WidgetAttributes(name: "T&T Run")
    }
}

extension T_T_WidgetAttributes.ContentState {
    fileprivate static var tracking: T_T_WidgetAttributes.ContentState {
        T_T_WidgetAttributes.ContentState(isTracking: true, lastSync: Date())
    }

    fileprivate static var idle: T_T_WidgetAttributes.ContentState {
        T_T_WidgetAttributes.ContentState(isTracking: false, lastSync: Date())
    }
}

#Preview("Notification", as: .content, using: T_T_WidgetAttributes.preview) {
   T_T_WidgetLiveActivity()
} contentStates: {
    T_T_WidgetAttributes.ContentState.tracking
    T_T_WidgetAttributes.ContentState.idle
}
