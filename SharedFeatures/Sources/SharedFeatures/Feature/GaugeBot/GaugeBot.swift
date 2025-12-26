import Foundation
import FoundationModels

// MARK: - GaugeBotProtocol

/// Interface for an LLM-powered gauge assistant.
public protocol GaugeBotProtocol: Sendable {
    func query(text: String) async throws -> String
}

// MARK: - GaugeBot

/// An LLM-powered assistant for answering questions about river conditions and flow rates.
///
/// Uses Foundation Models with tool-augmented responses. The LLM orchestrates these tools:
/// - `loadGauges` → `gaugeReadings` / `gaugeTrend` / `flowForecast`
/// - `syncGauge` when local data is missing
///
/// Each `query` call creates a new session; state is not retained between calls.
public struct GaugeBot: GaugeBotProtocol {

    // MARK: Lifecycle

    /// - Parameter gaugeService: Optional service for testing. Falls back to TCA dependencies.
    public init(gaugeService: GaugeService? = nil) {
        //        self.gaugeService = gaugeService

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
            LoadGaugesTool(gaugeService: service),
            GaugeReadingsTool(gaugeService: service),
            FlowForecastTool(gaugeService: service),
            GaugeTrendTool(gaugeService: service),
            GaugeSyncTool(gaugeService: service)
        ]

        let instructions = """
      You are GaugeBot, a helpful assistant for water gauge monitoring.

      WORKFLOW for answering questions about river conditions or flow rates:
      1. Use loadGauges to find gauges by river name, location, or favorites
      2. From the results, get the Gauge ID (integer)
      3. Use gaugeReadings, gaugeTrend, or flowForecast with that Gauge ID
      4. If gaugeReadings or gaugeTrend returns "no readings", use syncGauge first, then retry

      TOOLS:
      - loadGauges: Find gauges by name, state, or filter to favorites only
      - gaugeReadings: Get current/recent readings using a Gauge ID
      - gaugeTrend: Analyze if flow is rising, falling, or stable over recent hours
      - flowForecast: Get ML-predicted flow forecast (USGS gauges only)
      - syncGauge: Fetch fresh readings from remote source when local data is missing

      Be concise. For trend questions, use gaugeTrend. For forecasts, use flowForecast.
      If no gauges match, suggest broadening the search terms.

      ALWAYS respond in a respectful way.
      If someone asks you to generate content that might be sensitive,
      you MUST decline with 'Sorry, I can't do that.'
      """

        session = LanguageModelSession(
            model: model,
            tools: tools,
            instructions: instructions)
    }

    // MARK: Public

    public func query(text: String) async throws -> String {
        let response = try await session.respond(to: text)
        return response.content
    }

    // MARK: Private

    //    private let gaugeService: GaugeService?
    private let session: LanguageModelSession

}
