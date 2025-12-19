//
//  SearchGaugesTool.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import FoundationModels

// MARK: - SearchGaugesTool

/// Tool that searches for water gauges by name or location.
struct SearchGaugesTool: Tool {

    // MARK: Lifecycle

    init(gaugeService: GaugeService) {
        self.gaugeService = gaugeService
    }

    // MARK: Internal

    @Generable
    struct Arguments {
        @Guide(description: "Search term to find gauges by name (partial match)")
        var name: String?

        @Guide(description: "Two-letter US state code (e.g., 'CO', 'AK', 'CA')")
        var state: String?

        @Guide(description: "Two-letter country code (e.g., 'US', 'CA' for Canada)")
        var country: String?

        @Guide(description: "Maximum number of results to return (1-25)")
        var limit: Int?
    }

    let name = "searchGauges"
    let description = """
    Searches for water gauges by name or location. Use this when the user wants to find \
    gauges in a specific area, river, or by name. You can filter by state, country, or \
    search by name. Returns matching gauge information.
    """

    func call(arguments: Arguments) async throws -> String {
        // Build query options - clear defaults if user provides specific filters
        let options = GaugeQueryOptions(
            name: arguments.name,
            country: arguments.country ?? (arguments.state != nil ? "US" : nil),
            state: arguments.state,
            zone: nil,
            source: nil,
            favorite: nil,
            primary: nil,
            boundingBox: nil)

        let gauges = try await gaugeService.loadGauges(options)

        if gauges.isEmpty {
            var message = "No gauges found"
            if let name = arguments.name {
                message += " matching '\(name)'"
            }
            if let state = arguments.state {
                message += " in \(state)"
            }
            return message + "."
        }

        let limit = min(arguments.limit ?? 15, 25)
        let limitedGauges = Array(gauges.prefix(limit))
        let gaugeInfos = limitedGauges.map { GaugeInfo(from: $0.ref) }

        var result = "Found \(gauges.count) gauge(s)"
        if gauges.count > limit {
            result += " (showing first \(limit))"
        }
        result += ":\n\n"

        for (index, info) in gaugeInfos.enumerated() {
            result += """
        \(index + 1). \(info.name)
           Site ID: \(info.siteID)
           Location: \(info.state), \(info.country)
           Source: \(info.source.uppercased())
           Favorite: \(info.isFavorite ? "Yes" : "No")

        """
        }

        return result
    }

    // MARK: Private

    private let gaugeService: GaugeService

}
