//
//  GaugeWatcherApp.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//

import AppDatabase
import AppTelemetry
import ComposableArchitecture
import GaugeSources
import SQLiteData
import SwiftUI

// MARK: - GaugeWatcherApp

@main
struct GaugeWatcherApp: App {

    // MARK: Lifecycle

    init() {
        AppTelemetry.initialize()
        loadRocketSimConnect()
        do {
            try prepareDependencies {
                try $0.bootstrapDatabase()
            }
        } catch {
            fatalError("Failed to prepare database")
        }
    }

    // MARK: Internal

    var body: some Scene {
        WindowGroup {
            AppView(store: Store(initialState: AppFeature.State(), reducer: {
                AppFeature()
            }))
        }
    }

    // MARK: Private

    private func loadRocketSimConnect() {
        #if DEBUG
        guard
            Bundle(path: "/Applications/RocketSim.app/Contents/Frameworks/RocketSimConnectLinker.nocache.framework")?
                .load() == true
        else {
            print("Failed to load linker framework")
            return
        }
        print("RocketSim Connect successfully linked")
        #endif
    }
}
