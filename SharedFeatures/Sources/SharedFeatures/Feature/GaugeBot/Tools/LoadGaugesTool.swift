//
//  LoadGaugesTool.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/26/25.
//

import FoundationModels

// MARK: - LoadGaugesTool

/// Tool that loads water gauges from the database with optional filtering.
struct LoadGaugesTool: Tool {

    // MARK: Lifecycle

    init(gaugeService: GaugeService) {
        self.gaugeService = gaugeService
    }

    // MARK: Internal

    @Generable
    struct Arguments {
        @Guide(description: "Search keywords to find gauges (e.g., 'Potomac Little Falls')")
        var name: String?

        @Guide(description: "Two-letter US state code (e.g., 'CO', 'AK', 'CA', 'MD', 'VA')")
        var state: String?

        @Guide(description: "Two-letter country code (e.g., 'US', 'CA' for Canada)")
        var country: String?

        @Guide(description: "Filter to only show favorite gauges")
        var favoritesOnly: Bool?

        @Guide(description: "Maximum number of results to return (1-10)")
        var limit: Int?
    }

    let name = "loadGauges"
    let description = """
    Loads water gauges. Can search by name, filter by location, or show only favorites. \
    Use gaugeReadings to get actual data after finding gauges.
    """

    func call(arguments: Arguments) async throws -> String {
        let options = GaugeQueryOptions(
            name: arguments.name,
            country: arguments.country ?? (arguments.state != nil ? "US" : nil),
            state: arguments.state,
            zone: nil,
            source: nil,
            favorite: arguments.favoritesOnly,
            primary: nil,
            boundingBox: nil)

        let gauges = try await gaugeService.loadGauges(options)

        if gauges.isEmpty {
            return buildEmptyMessage(arguments: arguments)
        }

        // Small limit for on-device model context window
        let limit = min(arguments.limit ?? 5, 10)
        let limitedGauges = Array(gauges.prefix(limit))

        var result = "Found \(gauges.count) gauge(s)"
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

    private func buildEmptyMessage(arguments: Arguments) -> String {
        if arguments.favoritesOnly == true {
            return "No favorites saved."
        }

        var message = "No gauges found"
        if let name = arguments.name {
            message += " matching '\(name)'"
        }
        if let state = arguments.state {
            message += " in \(state)"
        }
        return message + "."
    }

}
