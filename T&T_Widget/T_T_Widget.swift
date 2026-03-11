//
//  T_T_Widget.swift
//  T&T_Widget
//
//  Home Screen / Lock Screen widget: "Tracking active" or "Last sync".
//  Add this file to a Widget Extension target and enable App Group: group.com.minutelongsolutions.T-T-Run
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), isTracking: true, lastSync: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.minutelongsolutions.T-T-Run")
        let entry = SimpleEntry(
            date: Date(),
            isTracking: defaults?.bool(forKey: "isTracking") ?? false,
            lastSync: defaults?.object(forKey: "lastSyncTime") as? Date ?? Date()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.minutelongsolutions.T-T-Run")
        let entry = SimpleEntry(
            date: Date(),
            isTracking: defaults?.bool(forKey: "isTracking") ?? false,
            lastSync: defaults?.object(forKey: "lastSyncTime") as? Date ?? Date()
        )
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let isTracking: Bool
    let lastSync: Date
}

struct WidgetExtensionEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.isTracking ? "location.fill" : "location.slash")
                    .foregroundStyle(entry.isTracking ? Color.green : Color.secondary)
                Text(entry.isTracking ? String(localized: "Tracking active") : String(localized: "Tracking off"))
                    .font(.caption)
            }
            Text("\(String(localized: "Last sync")): \(entry.lastSync.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct T_T_Widget: Widget {
    let kind: String = "TTRunWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("T&T Run")
        .description("Shows tracking status and last sync time.")
        #if os(watchOS)
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
        #else
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
        #endif
    }
}

// Previews require the main app scheme (e.g. "T&T Run"), not "T&T_WidgetExtension".
#Preview(as: .accessoryRectangular) {
    T_T_Widget()
} timeline: {
    SimpleEntry(date: .now, isTracking: true, lastSync: Date())
    SimpleEntry(date: .now, isTracking: false, lastSync: Date())
}    
