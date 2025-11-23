//
//  App.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//

import ComposableArchitecture
import GaugeSources
import SQLiteData
import SwiftUI

// MARK: - AppModel

@MainActor
@Observable
class AppModel { }

// MARK: - GaugeDetailModel

@MainActor
@Observable
final class GaugeDetailModel { }

// MARK: - AppView

struct AppView: View {

    @AppStorage("gauges-seeded") var seeded = false

    @Bindable var model: AppModel

    @Dependency(\.defaultDatabase)
    var database

    var body: some View {
        TabView {
            GaugeSearch(store: Store(initialState: GaugeSearchFeature.State(), reducer: {
                GaugeSearchFeature()
            }))
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0) // Assign a unique tag to each tab
            .task {
                seedDatabase()
            }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
    }

    func seedDatabase() {
        guard !seeded else { return }

        withErrorReporting {
            try database.write { db in
                try db.seedGaugeData()
            }
            seeded = true
        }
    }
}

extension Database {
    func seedGaugeData() throws {
        let gaugeData = try GaugeSources.load()

        try seed {
            for (index, gauge) in gaugeData.enumerated() {
                Gauge.Draft(
                    id: index + 1,
                    name: gauge.name,
                    siteID: gauge.siteID,
                    metric: gauge.metric,
                    country: gauge.country,
                    state: gauge.state,
                    zone: gauge.zone ?? "",
                    source: gauge.source!,
                    latitude: Double(gauge.latitude),
                    longitude: Double(gauge.longitude),
                    updatedAt: .distantPast,
                    createdAt: .now)
            }
        }
    }
}
