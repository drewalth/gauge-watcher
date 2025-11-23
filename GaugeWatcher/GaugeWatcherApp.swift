//
//  GaugeWatcherApp.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//

import ComposableArchitecture
import GaugeSources
import SQLiteData
import SwiftUI

// MARK: - GaugeWatcherApp

@main
struct GaugeWatcherApp: App {
    init() {
        try! prepareDependencies {
            try $0.bootstrapDatabase()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Store(initialState: AppFeature.State(), reducer: {
                AppFeature()
            }))
        }
    }
}
