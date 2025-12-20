//
//  GaugeTrendTool.swift
//  SharedFeatures
//
//  Created by Andrew Althage on 12/20/25.
//

import Foundation
import FoundationModels
import GaugeService

// MARK: - GaugeTrendTool

/// Tool that analyzes gauge readings to determine if flow is rising, falling, or stable.
struct GaugeTrendTool: Tool {

    // MARK: Lifecycle

    init(gaugeService: GaugeService) {
        self.gaugeService = gaugeService
    }

    // MARK: Internal

    @Generable
    struct Arguments {
        @Guide(description: "The internal gauge ID (integer) to analyze")
        var gaugeID: Int

        @Guide(description: "Hours of data to analyze (1-48, default 6)")
        var hours: Int?
    }

    let name = "gaugeTrend"
    let description = """
    Analyzes recent readings to determine if a gauge is rising, falling, or stable. \
    Returns trend direction, rate of change, and percentage change.
    """

    func call(arguments: Arguments) async throws -> String {
        let hours = min(max(arguments.hours ?? 6, 1), 48)

        let readings = try await gaugeService.loadGaugeReadings(
            .lastHours(hours, gaugeID: arguments.gaugeID))

        guard readings.count >= 2 else {
            if readings.count == 1 {
                let reading = readings[0]
                return "Only 1 reading in the last \(hours) hours: \(formatValue(reading.value)) \(reading.metric). Need more data for trend analysis."
            }
            return "No readings in the last \(hours) hours for gauge \(arguments.gaugeID)."
        }

        // Readings are sorted newest first, so last is oldest
        let newest = readings[0]
        let oldest = readings[readings.count - 1]

        let valueDelta = newest.value - oldest.value
        let timeDeltaHours = newest.createdAt.timeIntervalSince(oldest.createdAt) / 3600

        guard timeDeltaHours > 0 else {
            return "Current reading: \(formatValue(newest.value)) \(newest.metric)"
        }

        let ratePerHour = valueDelta / timeDeltaHours
        let percentChange = (valueDelta / oldest.value) * 100

        let trend = classifyTrend(percentChange: percentChange, hours: timeDeltaHours)

        var result = "\(trend.emoji) \(trend.label)\n"
        result += "• Current: \(formatValue(newest.value)) \(newest.metric)\n"
        result += "• \(Int(timeDeltaHours))h ago: \(formatValue(oldest.value)) \(oldest.metric)\n"
        result += "• Change: \(formatDelta(valueDelta)) (\(formatPercent(percentChange)))\n"
        result += "• Rate: \(formatDelta(ratePerHour))/hour"

        return result
    }

    // MARK: Private

    private let gaugeService: GaugeService

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func formatDelta(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        if abs(value) >= 1000 {
            return "\(sign)\(String(format: "%.0f", value))"
        }
        return "\(sign)\(String(format: "%.1f", value))"
    }

    private func formatPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))%"
    }

    private func classifyTrend(percentChange: Double, hours: Double) -> Trend {
        // Normalize to approximate daily rate for classification
        let dailyRate = percentChange * (24 / hours)

        switch dailyRate {
        case 50...:
            return .risingRapidly
        case 15..<50:
            return .rising
        case 5..<15:
            return .risingSlowly
        case -5..<5:
            return .stable
        case -15 ..< -5:
            return .fallingSlowly
        case -50 ..< -15:
            return .falling
        default:
            return .fallingRapidly
        }
    }

}

// MARK: GaugeTrendTool.Trend

extension GaugeTrendTool {
    enum Trend {
        case risingRapidly
        case rising
        case risingSlowly
        case stable
        case fallingSlowly
        case falling
        case fallingRapidly

        var label: String {
            switch self {
            case .risingRapidly: "Rising rapidly"
            case .rising: "Rising"
            case .risingSlowly: "Rising slowly"
            case .stable: "Stable"
            case .fallingSlowly: "Falling slowly"
            case .falling: "Falling"
            case .fallingRapidly: "Falling rapidly"
            }
        }

        var emoji: String {
            switch self {
            case .risingRapidly: "⬆️"
            case .rising: "↗️"
            case .risingSlowly: "↗️"
            case .stable: "➡️"
            case .fallingSlowly: "↘️"
            case .falling: "↘️"
            case .fallingRapidly: "⬇️"
            }
        }
    }
}

