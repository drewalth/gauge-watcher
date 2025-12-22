//
//  GaugeSyncTool.swift
//  SharedFeatures
//
//  Created by Andrew Althage on 12/21/25.
//

import Foundation
import FoundationModels

/// Tool that fetches and syncs gauge readings from the remote data source.
/// Use this when readings are missing or stale in the local database.
struct GaugeSyncTool: Tool {

    // MARK: Lifecycle

    init(gaugeService: GaugeService) {
        self.gaugeService = gaugeService
    }

    // MARK: Internal

    @Generable
    struct Arguments {
        @Guide(description: "The internal gauge ID (integer) to sync readings for")
        var gaugeID: Int
    }

    let name = "syncGauge"
    let description = """
    Fetches the latest readings from the remote data source (USGS, Environment Canada, etc.) \
    and saves them to the local database. Use this when gaugeReadings returns no data or \
    when you need fresh data. After syncing, use gaugeReadings to retrieve the data.
    """

    func call(arguments: Arguments) async throws -> String {
        do {
            // Load gauge first to get its name for the response
            let gauge = try await gaugeService.loadGauge(arguments.gaugeID)

            // Perform the sync
            try await gaugeService.sync(arguments.gaugeID)

            return "Synced readings for \(gauge.name) (ID: \(arguments.gaugeID)). Use gaugeReadings to view the data."
        } catch {
            return "Failed to sync gauge \(arguments.gaugeID): \(error.localizedDescription)"
        }
    }

    // MARK: Private

    private let gaugeService: GaugeService

}
