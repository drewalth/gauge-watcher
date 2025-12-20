//
//  FlowForecastTool.swift
//  SharedFeatures
//
//  Created by Andrew Althage on 12/20/25.
//

import Foundation
import FoundationModels
import GaugeDrivers
import GaugeService

/// Tool that returns ML-predicted flow forecasts for USGS gauges.
struct FlowForecastTool: Tool {

    // MARK: Lifecycle

    init(gaugeService: GaugeService) {
        self.gaugeService = gaugeService
    }

    // MARK: Internal

    @Generable
    struct Arguments {
        @Guide(description: "The internal gauge ID (integer) to get forecast for")
        var gaugeID: Int
    }

    let name = "flowForecast"
    let description = """
    Returns ML-predicted flow forecast for a USGS gauge. Only works for USGS gauges. \
    Use searchGauges first to find the gauge ID, then call this with that ID.
    """

    func call(arguments: Arguments) async throws -> String {
        // Load the gauge to get siteID and verify it's USGS
        let gauge = try await gaugeService.loadGauge(arguments.gaugeID)

        guard gauge.source == .usgs else {
            return "Forecast unavailable: only USGS gauges support flow forecasting. This gauge uses \(gauge.source.rawValue)."
        }

        let forecast = try await gaugeService.forecast(gauge.siteID, USGS.USGSParameter.discharge)

        if forecast.isEmpty {
            return "No forecast data available for \(gauge.name)."
        }

        // Filter to upcoming forecasts (today and next 7 days max)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let oneWeekOut = calendar.date(byAdding: .day, value: 7, to: today) ?? today

        // Aggressive filtering to avoid context overflow - service returns thousands of points
        let upcomingForecasts = forecast
            .filter { $0.index >= today && $0.index <= oneWeekOut }
            .sorted { $0.index < $1.index }

        if upcomingForecasts.isEmpty {
            return "No upcoming forecast data available for \(gauge.name)."
        }

        // Ultra-concise: only show 3 days for on-device model context window
        let limitedForecasts = Array(upcomingForecasts.prefix(3))

        // Calculate trend from first to last forecast point
        let trend = calculateTrend(from: limitedForecasts)

        var result = "\(gauge.name) forecast (\(trend)):\n"
        for point in limitedForecasts {
            let dateStr = point.index.formatted(date: .abbreviated, time: .omitted)
            let value = Int(point.value)
            result += "• \(dateStr): \(value) CFS\n"
        }

        return result
    }

    // MARK: Private

    private let gaugeService: GaugeService

    private func calculateTrend(from forecasts: [ForecastDataPoint]) -> String {
        guard forecasts.count >= 2,
              let first = forecasts.first,
              let last = forecasts.last else {
            return "stable"
        }

        let change = last.value - first.value
        let percentChange = (change / first.value) * 100

        switch percentChange {
        case 20...: return "rising sharply"
        case 5..<20: return "rising"
        case -5..<5: return "stable"
        case -20 ..< -5: return "falling"
        default: return "falling sharply"
        }
    }

}

