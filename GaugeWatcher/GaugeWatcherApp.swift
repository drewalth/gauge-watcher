//
//  GaugeWatcherApp.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//

import AppTelemetry
import SharedFeatures
import SwiftUI

// MARK: - GaugeWatcherApp

@main
struct GaugeWatcherApp: SwiftUI.App {

    // MARK: Lifecycle

    init() {
        AppTelemetry.initialize()
        AppDatabase.initialize()
        loadRocketSimConnect()
    }

    // MARK: Internal

    var body: some Scene {
        WindowGroup {
            AppView(store: Store(initialState: AppFeature.State(), reducer: {
                AppFeature()
            })).fontDesign(.monospaced)
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
