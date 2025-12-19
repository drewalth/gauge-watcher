//
//  LoadFavoriteGaugesTool.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import FoundationModels
import SharedFeatures

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
    @Guide(description: "Maximum number of favorites to return (1-50)")
    var limit: Int?
  }

  let name = "loadFavoriteGauges"
  let description = """
    Loads the user's favorite water gauges from their saved list. \
    Returns gauge names, locations, and site IDs. Use this when the user asks \
    about their favorites, saved gauges, or wants to check on specific gauges they track.
    """

  func call(arguments: Arguments) async throws -> String {
    let gauges = try await gaugeService.loadFavoriteGauges()

    if gauges.isEmpty {
      return "No favorite gauges found. The user hasn't added any gauges to their favorites yet."
    }

    let limit = min(arguments.limit ?? 50, 50)
    let limitedGauges = Array(gauges.prefix(limit))
    let gaugeInfos = limitedGauges.map { GaugeInfo(from: $0.ref) }

    // Format as readable text for the LLM
    var result = "Found \(gauges.count) favorite gauge(s)"
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
           Coordinates: \(info.latitude), \(info.longitude)
           Last Updated: \(info.lastUpdated)

        """
    }

    return result
  }

  // MARK: Private

  private let gaugeService: GaugeService

}
