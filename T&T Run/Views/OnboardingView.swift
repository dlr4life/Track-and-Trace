//
//  OnboardingView.swift
//  T&T Run
//
//  Infographic-style tutorial with app-related steps. Shown once for first-time users; display controlled by showOnboarding.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    var onComplete: () -> Void

    @State private var currentPage = 0
    private let pages: [OnboardingPage] = OnboardingPage.allSteps

    var body: some View {
        ZStack {
            onboardingBackground
            VStack(spacing: 0) {
                tabContent
                pageIndicatorAndButtons
            }
        }
        .ignoresSafeArea()
    }

    private var onboardingBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.09, blue: 0.16),
                Color(red: 0.1, green: 0.14, blue: 0.24)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var tabContent: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                OnboardingPageView(page: page, pageIndex: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.25), value: currentPage)
    }

    private var pageIndicatorAndButtons: some View {
        VStack(spacing: 24) {
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? AppTheme.accentColor : Color.white.opacity(0.3))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button {
                        withAnimation { currentPage -= 1 }
                    } label: {
                        Text(String(localized: "Back"))
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        markOnboardingComplete()
                        onComplete()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? String(localized: "Next") : String(localized: "Get Started"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.accentColor, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusButton))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppTheme.padding)
        }
        .padding(.bottom, 48)
        .padding(.top, 24)
    }

    /// Onboarding display logic: only the showOnboarding flag controls whether we show onboarding.
    /// When user completes onboarding we set showOnboarding = true so it does not show repeatedly.
    private func markOnboardingComplete() {
        settings.showOnboarding = true
    }
}

// MARK: - Page model and content

struct OnboardingPage {
    let title: String
    let subtitle: String
    let iconName: String
    let preview: OnboardingPreviewKind

    static let allSteps: [OnboardingPage] = [
        OnboardingPage(
            title: String(localized: "Welcome to T&T Run"),
            subtitle: String(localized: "Track your runs and sync locations to your organization’s map. Follow these steps to get the most out of the app."),
            iconName: "location.circle.fill",
            preview: .welcome
        ),
        OnboardingPage(
            title: String(localized: "Map & tracking"),
            subtitle: String(localized: "The main map shows your position and recorded track. The status bar shows tracking state and last sync. Tap the gear to open Settings."),
            iconName: "map.fill",
            preview: .map
        ),
        OnboardingPage(
            title: String(localized: "Settings & sync"),
            subtitle: String(localized: "Configure your Feature Service URL and layer in Settings to sync tracks to ArcGIS. You can also set theme, privacy, and export options."),
            iconName: "gearshape.2.fill",
            preview: .settings
        ),
        OnboardingPage(
            title: String(localized: "You’re all set"),
            subtitle: String(localized: "Open the Map tab to start tracking. Use the Home tab for a quick overview. You can reset this tutorial anytime from Settings."),
            iconName: "checkmark.circle.fill",
            preview: .done
        )
    ]
}

enum OnboardingPreviewKind {
    case welcome
    case map
    case settings
    case done
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let pageIndex: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                previewCard
                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(page.subtitle)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AppTheme.padding)
            }
            .padding(.top, 52)
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        switch page.preview {
        case .welcome:
            previewBox {
                Image(systemName: page.iconName)
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.accentColor)
            }
        case .map:
            previewBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 80, height: 24)
                        Spacer()
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(AppTheme.successColor)
                        Text(String(localized: "Tracking on"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text(String(localized: "Last sync"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                        .frame(height: 120)
                        .overlay(
                            Image(systemName: "map")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.5))
                        )
                }
                .padding(16)
            }
        case .settings:
            previewBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label(String(localized: "Feature Service"), systemImage: "link")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.9))
                    Text(String(localized: "URL & Layer ID"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Divider().background(Color.white.opacity(0.2))
                    Label(String(localized: "Theme"), systemImage: "paintbrush")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                    Label(String(localized: "Export track"), systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        case .done:
            previewBox {
                Image(systemName: page.iconName)
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.successColor)
            }
        }
    }

    private func previewBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(minHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 28)
    }
}

#Preview {
    OnboardingView(settings: AppSettings.shared, onComplete: {})
}
