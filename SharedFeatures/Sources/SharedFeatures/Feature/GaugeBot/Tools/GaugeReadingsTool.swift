//
//  GaugeReadingsTool.swift
//  SharedFeatures
//
//  Created by Andrew Althage on 12/19/25.
//

// this tool will return the latest readings for a given gauge

import FoundationModels
import Foundation

/// Tool that returns the latest readings for a specific gauge.
struct GaugeReadingsTool: Tool {

    // MARK: Lifecycle

    init(gaugeService: GaugeService) {
        self.gaugeService = gaugeService
    }

    // MARK: Internal

    @Generable
    struct Arguments {
        @Guide(description: "The internal gauge ID (integer) to return readings for")
        var gaugeID: Int
        @Guide(description: "Number of recent readings to return (1-10, default 1)")
        var limit: Int?
    }

    let name = "gaugeReadings"
    let description = """
    Returns recent readings for a gauge. For current flow rate, use limit=1. \
    Returns value, metric, and timestamp.
    """

    func call(arguments: Arguments) async throws -> String {
        // Enforce small limit for on-device model context window
        let limit = min(arguments.limit ?? 1, 10)

        let readings = try await gaugeService.loadGaugeReadings(
            GaugeReadingQuery(
                gaugeID: arguments.gaugeID,
                limit: limit))

        if readings.isEmpty {
            return "No readings found for gauge \(arguments.gaugeID)."
        }

        // Concise output for small context window
        if readings.count == 1, let reading = readings.first {
            return "Gauge \(arguments.gaugeID): \(reading.value) \(reading.metric) at \(reading.createdAt.formatted(date: .abbreviated, time: .shortened))"
        }

        var result = "Gauge \(arguments.gaugeID) readings:\n"
        for reading in readings {
            result += "• \(reading.value) \(reading.metric) (\(reading.createdAt.formatted(date: .abbreviated, time: .shortened)))\n"
        }
        return result
    }

    // MARK: Private

    private let gaugeService: GaugeService

}
