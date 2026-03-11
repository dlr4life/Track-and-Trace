//
//  RootView.swift
//  T&T Run
//
//  Root flow: Splash → (Onboarding when showOnboarding is false) → MainTabView.
//  Onboarding display is determined only by the showOnboarding flag; onAppear logic decides when to present it.
//

import SwiftUI

struct RootView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var splashFinished = false
    @State private var showOnboardingOverlay = false

    var body: some View {
        Group {
            if !splashFinished {
                SplashImageView(onFinish: handleSplashFinished)
            } else {
                MainTabView()
                    .fullScreenCover(isPresented: $showOnboardingOverlay) {
                        OnboardingView(settings: settings) {
                            settings.showOnboarding = true
                            showOnboardingOverlay = false
                        }
                    }
                    .onAppear {
                        decideOnboardingPresentation()
                    }
            }
        }
    }

    /// Called when splash animation finishes. Onboarding display logic: only check showOnboarding flag.
    private func handleSplashFinished() {
        splashFinished = true
        if !settings.showOnboarding {
            showOnboardingOverlay = true
        }
    }

    /// onAppear logic: determine when to show onboarding. Prevents onboarding from showing repeatedly when not needed.
    private func decideOnboardingPresentation() {
        guard splashFinished else { return }
        if !settings.showOnboarding, !showOnboardingOverlay {
            showOnboardingOverlay = true
        }
    }
}

#Preview {
    RootView()
}
