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
import os

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
    
    private let logger = Logger(category: "AppView")

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
            .tag(0)
            .task {
                await seedDatabase()
            }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
    }

    func seedDatabase() async {
        guard !seeded else { return }

        do {
            // Load gauge data asynchronously
            let gaugeData = try await GaugeSources.loadAll()
            
            try await Task {
                try self.database.write { db in
                    try db.seedGaugeData(gaugeData)
                }
            }.value
            
            seeded = true
        } catch {
            // Log error but don't crash the app
            logger.error("Failed to seed database: \(error.localizedDescription)")
        }
    }
}

extension Database {
    func seedGaugeData(_ gaugeData: [GaugeSourceItem]) throws {
        // Filter out any items without a source before seeding
        let validGauges = gaugeData.filter { $0.source != nil }
        
        try seed {
            for (index, gauge) in validGauges.enumerated() {
                Gauge.Draft(
                    id: index + 1,
                    name: gauge.name,
                    siteID: gauge.siteID,
                    metric: gauge.metric,
                    country: gauge.country,
                    state: gauge.state,
                    zone: gauge.zone ?? "",
                    source: gauge.source!, // Safe because we filtered
                    latitude: Double(gauge.latitude),
                    longitude: Double(gauge.longitude),
                    updatedAt: .distantPast,
                    createdAt: .now
                )
            }
        }
    }
}
