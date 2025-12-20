//
//  GaugeWatcherMacApp.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/16/25.
//

import AppDatabase
import AppTelemetry
import SharedFeatures
import SwiftUI

// MARK: - GaugeWatcherMacApp

@main
struct GaugeWatcherMacApp: App {

    // MARK: Lifecycle

    init() {
        AppTelemetry.initialize()
        AppDatabase.initialize()
        OnboardingTips.initialize()
    }

    // MARK: Internal

    var body: some Scene {
        WindowGroup {
            RootView()
                .fontDesign(.monospaced)
                .frame(
                    minWidth: 1000, // Be honest about what you need
                    maxWidth: .infinity,
                    minHeight: 600,
                    maxHeight: .infinity)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1281, height: 833)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }
    }
}

// MARK: - RootView

private struct RootView: View {

    // MARK: Internal

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

    // MARK: Private

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

}
