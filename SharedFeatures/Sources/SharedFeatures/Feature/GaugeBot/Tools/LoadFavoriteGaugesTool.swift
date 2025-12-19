//
//  LoadFavoriteGaugesTool.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import FoundationModels

// MARK: - LoadFavoriteGaugesTool

/// Tool that loads the user's favorite water gauges from the database.
struct LoadFavoriteGaugesTool: Tool {

    // MARK: Lifecycle

    init(gaugeService: GaugeService) {
        self.gaugeService = gaugeService
    }

    // MARK: Internal

    @Generable
    struct Arguments {
        @Guide(description: "Maximum number of favorites to return (1-10)")
        var limit: Int?
    }

    let name = "loadFavoriteGauges"
    let description = """
    Lists user's favorite gauges with their IDs. Use gaugeReadings to get actual data.
    """

    func call(arguments: Arguments) async throws -> String {
        let gauges = try await gaugeService.loadFavoriteGauges()

        if gauges.isEmpty {
            return "No favorites saved."
        }

        // Small limit for on-device model context window
        let limit = min(arguments.limit ?? 10, 10)
        let limitedGauges = Array(gauges.prefix(limit))

        var result = "\(gauges.count) favorite(s)"
        if gauges.count > limit {
            result += " (showing \(limit))"
        }
        result += ":\n"

        for gauge in limitedGauges {
            result += "• \(gauge.name) [ID: \(gauge.id)] - \(gauge.state)\n"
        }

        return result
    }

    // MARK: Private

    private let gaugeService: GaugeService

}
