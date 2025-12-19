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
        @Guide(description: "The metric of the readings to return")
        var metric: String?
        @Guide(description: "Start date for readings in ISO8601 format (e.g. 2025-01-01T00:00:00Z)")
        var startDate: String?
        @Guide(description: "End date for readings in ISO8601 format (e.g. 2025-01-31T23:59:59Z)")
        var endDate: String?
        @Guide(description: "The limit of the readings to return")
        var limit: Int?
    }

    let name = "gaugeReadings"
    let description = """
    Returns the latest readings for a given gauge. Use this when the user asks \
    about the latest readings or flow rate of a specific gauge.
    """

    func call(arguments: Arguments) async throws -> String {
        let dateRange: DateInterval? = {
            guard let startString = arguments.startDate,
                  let endString = arguments.endDate,
                  let start = try? Date(startString, strategy: .iso8601),
                  let end = try? Date(endString, strategy: .iso8601)
            else { return nil }
            return DateInterval(start: start, end: end)
        }()

        let readings = try await gaugeService.loadGaugeReadings(
            GaugeReadingQuery(
                gaugeID: arguments.gaugeID,
                dateRange: dateRange,
                metric: arguments.metric,
                limit: arguments.limit))

        if readings.isEmpty {
            return "No readings found for gauge ID \(arguments.gaugeID)."
        }

        // Format as readable text for the LLM
        var result = "Found \(readings.count) reading(s) for gauge ID \(arguments.gaugeID)"
        result += ":\n\n"

        for (index, reading) in readings.enumerated() {
            result += """
        \(index + 1). \(reading.createdAt.formatted(date: .abbreviated, time: .shortened))
           Value: \(reading.value)
           Metric: \(reading.metric)

        """
        }

        return result
    }

    // MARK: Private

    private let gaugeService: GaugeService

}
