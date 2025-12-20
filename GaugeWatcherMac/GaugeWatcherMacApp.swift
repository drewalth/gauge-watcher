//
//  GaugeWatcherMacApp.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/16/25.
//

import AppTelemetry
import SharedFeatures
import SwiftUI

// MARK: - GaugeWatcherMacApp

@main
struct GaugeWatcherMacApp: App {

    // MARK: Lifecycle

    init() {
        AppTelemetry.initialize()
        do {
            try prepareDependencies {
                try $0.bootstrapDatabase()
            }
        } catch {
            fatalError("Failed to prepare database: \(error)")
        }
    }

    // MARK: Internal

    var body: some Scene {
        WindowGroup {
            RootView()
                .fontDesign(.monospaced)
                .frame(
                    minWidth: 800,
                    maxWidth: .infinity,
                    minHeight: 600,
                    maxHeight: .infinity)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1281, height: 833)  // 2562×1666 @2x. best for app store screenshot
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }
    }
}

// MARK: - RootView

private struct RootView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            ContentView(store: Store(initialState: AppFeature.State()) {
                AppFeature()
            })
        } else {
            OnboardingView(
                store: Store(initialState: OnboardingReducer.State()) {
                    OnboardingReducer()
                },
                onComplete: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hasCompletedOnboarding = true
                    }
                })
        }
    }
}
