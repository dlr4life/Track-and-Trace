//
//  AppTheme.swift
//  T&T Run
//
//  Shared layout and visual constants for enterprise-level consistency.
//  Semantic colors support light/dark and accessibility.
//

import SwiftUI
import UIKit

enum AppTheme {
    // MARK: - Layout
    /// Standard horizontal padding for content and overlays.
    static let padding: CGFloat = 16
    /// Compact padding for inline elements.
    static let paddingCompact: CGFloat = 8
    /// Corner radius for cards and overlays.
    static let cornerRadius: CGFloat = 12
    /// Corner radius for buttons and chips.
    static let cornerRadiusButton: CGFloat = 8
    /// Minimum touch target for icon buttons (accessibility).
    static let minTouchTarget: CGFloat = 44
    /// Track polyline width on map.
    static let trackLineWidth: CGFloat = 3

    // MARK: - Typography
    /// Primary label font for section headers.
    static let sectionTitle = Font.headline
    /// Body/caption for descriptions.
    static let body = Font.body
    static let caption = Font.caption

    /// Opacity for secondary text.
    static let secondaryOpacity: Double = 0.8

    // MARK: - Semantic colors (SwiftUI)
    /// Success / tracking on.
    static let successColor = Color.green
    /// Warning / paused.
    static let warningColor = Color.orange
    /// Error / sync failure.
    static let errorColor = Color.red
    /// Track line on map.
    static let trackLineColor = Color.blue
    /// Clustering / map symbols (consistent with track).
    static let accentColor = Color.blue

    // MARK: - UIKit bridge (for ArcGIS symbols)
    static let trackLineUIColor: UIColor = .systemBlue
    static let accentUIColor: UIColor = .systemBlue
}
