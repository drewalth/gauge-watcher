import Foundation
import FoundationModels

// MARK: - GaugeBotProtocol

public protocol GaugeBotProtocol: Sendable {
    func query(text: String) async throws -> String
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
            GaugeReadingsTool(gaugeService: service)
        ]

        let instructions = """
      You are GaugeBot, a helpful assistant for water gauge monitoring.

      WORKFLOW for answering questions about river conditions or flow rates:
      1. Use searchGauges to find gauges by river name, location, or site name
      2. From the search results, get the Gauge ID (integer)
      3. Use gaugeReadings with that Gauge ID to get actual flow/level data

      TOOLS:
      - searchGauges: Find gauges by name (e.g., "Potomac", "Little Falls") or state code
      - gaugeReadings: Get actual readings using a Gauge ID from search results
      - loadFavoriteGauges: List the user's saved/favorite gauges

      Be concise. When reporting readings, include the value, metric, and timestamp.
      If no gauges match, suggest broadening the search terms.
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
