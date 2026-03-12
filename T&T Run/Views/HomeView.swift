//
//  HomeView.swift
//  T&T Run
//
//  Enterprise home/dashboard: quick overview and entry points to Map and Settings.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var authManager = AuthManager.shared
    var onOpenMap: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    welcomeSection
                    quickActionsSection
                    statusSection
                }
                .padding(AppTheme.padding)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(AppCopy.appName)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Track & Trace"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(localized: "View the map to see your position and recorded track. Sync is configured in Settings."))
                .font(AppTheme.body)
                .foregroundStyle(.primary)
        }
        .padding(AppTheme.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Quick actions"))
                .font(AppTheme.sectionTitle)
                .foregroundStyle(.primary)
            VStack(spacing: 0) {
                Button {
                    onOpenMap?()
                } label: {
                    quickActionRow(
                        icon: "map.fill",
                        title: AppCopy.mapTitle,
                        subtitle: String(localized: "Track and view your route")
                    )
                }
                .buttonStyle(.plain)
                Divider()
                    .padding(.leading, 52)
                Button {
                    onOpenSettings?()
                } label: {
                    quickActionRow(
                        icon: "gearshape.fill",
                        title: AppCopy.settingsTitle,
                        subtitle: String(localized: "Feature service, theme, export")
                    )
                }
                .buttonStyle(.plain)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    private func quickActionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.accentColor)
                .frame(width: 32, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.padding)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Status"))
                .font(AppTheme.sectionTitle)
                .foregroundStyle(.primary)
            HStack(spacing: 16) {
                statusChip(
                    icon: settings.trackingPaused ? "pause.circle" : "location.fill",
                    label: settings.trackingPaused ? String(localized: "Tracking paused") : String(localized: "Tracking on"),
                    color: settings.trackingPaused ? AppTheme.warningColor : AppTheme.successColor
                )
                if authManager.isSignedIn {
                    statusChip(
                        icon: "person.crop.circle.fill",
                        label: authManager.portalUser ?? String(localized: "Signed in"),
                        color: AppTheme.accentColor
                    )
                }
            }
            .padding(AppTheme.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    private func statusChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(label)
                .font(.subheadline)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.15), in: Capsule())
    }
}

#Preview {
    HomeView(settings: AppSettings.shared)
}
