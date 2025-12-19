import Foundation
import FoundationModels

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
            SearchGaugesTool(gaugeService: service)
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
