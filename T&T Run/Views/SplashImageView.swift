//
//  SplashImageView.swift
//  T&T Run
//
//  Enterprise splash with app-related animated graphics. Shown once at launch.
//

import SwiftUI

struct SplashImageView: View {
    var onFinish: () -> Void

    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var pulseScale: CGFloat = 0.8
    @State private var pulseOpacity: Double = 0.5
    @State private var trackRingRotation: Double = 0
    @State private var trackRingOpacity: Double = 0
    @State private var locationDotScale: CGFloat = 0.5
    @State private var locationDotOpacity: Double = 0

    private let splashDuration: TimeInterval = 2.2

    var body: some View {
        ZStack {
            gradientBackground
            VStack(spacing: 32) {
                appIconAndAnimation
                appTitle
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .onAppear {
            runAnimations()
        }
    }

    private var gradientBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.14),
                Color(red: 0.08, green: 0.12, blue: 0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var appIconAndAnimation: some View {
        ZStack {
            // Outer track ring (route/path)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.accentColor.opacity(0.6), AppTheme.trackLineColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 140, height: 140)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .rotationEffect(.degrees(trackRingRotation))

            // Second ring
            Circle()
                .stroke(AppTheme.trackLineColor.opacity(0.25), lineWidth: 2)
                .frame(width: 120, height: 120)
                .scaleEffect(pulseScale * 0.95)
                .opacity(trackRingOpacity)
                .rotationEffect(.degrees(-trackRingRotation * 0.7))

            // App icon / logo area
            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.35, blue: 0.7),
                                Color(red: 0.1, green: 0.25, blue: 0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)

                // Location pin / run icon
                Image(systemName: "location.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.white)
                    .scaleEffect(locationDotScale)
                    .opacity(locationDotOpacity)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
        }
        .frame(height: 200)
    }

    private var appTitle: some View {
        VStack(spacing: 8) {
            Text(AppCopy.appName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(String(localized: "Track & Trace"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .opacity(logoOpacity)
    }

    private func runAnimations() {
        withAnimation(.easeOut(duration: 0.5)) {
            logoOpacity = 1
            logoScale = 1
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            locationDotOpacity = 1
            locationDotScale = 1
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.4)) {
            pulseScale = 1.15
            pulseOpacity = 0.25
        }
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false).delay(0.3)) {
            trackRingRotation = 360
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            trackRingOpacity = 0.7
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) {
            withAnimation(.easeInOut(duration: 0.35)) {
                onFinish()
            }
        }
    }
}

#Preview {
    SplashImageView(onFinish: {})
}
