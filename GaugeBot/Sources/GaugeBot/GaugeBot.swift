import Foundation
import FoundationModels
import SharedFeatures

// MARK: - GaugeBotProtocol

public protocol GaugeBotProtocol: Sendable {
  func query(text: String) async throws -> String
}

#if os(macOS)

// MARK: - GaugeInfo

/// Simplified gauge representation for LLM tool output
struct GaugeInfo: Codable, Sendable {

  // MARK: Lifecycle

  init(from gauge: GaugeRef) {
    id = gauge.id
    name = gauge.name
    siteID = gauge.siteID
    country = gauge.country
    state = gauge.state
    source = gauge.source.rawValue
    latitude = gauge.latitude
    longitude = gauge.longitude
    isFavorite = gauge.favorite
    lastUpdated = gauge.updatedAt.formatted(date: .abbreviated, time: .shortened)
  }

  // MARK: Internal

  let id: Int
  let name: String
  let siteID: String
  let country: String
  let state: String
  let source: String
  let latitude: Double
  let longitude: Double
  let isFavorite: Bool
  let lastUpdated: String

}

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

// MARK: - GaugeBot

public struct GaugeBot: GaugeBotProtocol {

  // MARK: Lifecycle

  public init(gaugeService: GaugeService? = nil) {
    self.gaugeService = gaugeService
  }

  // MARK: Public

  public func query(text: String) async throws -> String {
    let model = SystemLanguageModel.default

    // Use provided service or get from TCA dependencies
    let service: GaugeService
    if let providedService = gaugeService {
      service = providedService
    } else {
      @Dependency(\.gaugeService) var dependencyService
      service = dependencyService
    }

    let tools: [any Tool] = [
      LoadFavoriteGaugesTool(gaugeService: service),
      SearchGaugesTool(gaugeService: service),
    ]

    let instructions = """
      You are GaugeBot, a helpful assistant for water gauge monitoring. You help users:
      - Find and learn about water gauges (river flow monitors)
      - Check their favorite/saved gauges
      - Search for gauges by location or name
      - Understand gauge data and water conditions

      When users ask about gauges, use the available tools to look up real data.
      Be concise but informative. If a user asks about a specific river or location,
      use the search tool to find relevant gauges.
      """

    let session = LanguageModelSession(
      model: model,
      tools: tools,
      instructions: instructions)

    let response = try await session.respond(to: text)
    return response.content
  }

  // MARK: Private

  private let gaugeService: GaugeService?

}

#else

// MARK: - GaugeBot

public struct GaugeBot: GaugeBotProtocol {

  // MARK: Lifecycle

  public init(gaugeService _: GaugeService? = nil) { }

  // MARK: Public

  public func query(text _: String) async throws -> String {
    "GaugeBot is not available on this platform. Apple Intelligence is required."
  }
}

#endif


