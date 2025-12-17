//
//  GaugeWatcherMacApp.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/16/25.
//

import SharedFeatures
import SwiftUI

// MARK: - GaugeWatcherMacApp

@main
struct GaugeWatcherMacApp: App {

    // MARK: Lifecycle

    init() {
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
            ContentView(store: Store(initialState: AppFeature.State()) {
                AppFeature()
            })
            .frame(
                minWidth: 800,
                maxWidth: .infinity,
                minHeight: 600,
                maxHeight: .infinity)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }
    }
}
