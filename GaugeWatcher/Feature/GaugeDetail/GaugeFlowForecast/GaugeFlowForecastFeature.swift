//
//  GaugeFlowForecastFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/28/25.
//

import ComposableArchitecture
import FlowForecast
import Foundation
import GaugeSources
import Loadable
import os

// MARK: - GaugeFlowForecastFeature

@Reducer
struct GaugeFlowForecastFeature {

    // MARK: Internal

    @ObservableState
    struct State {
        var forecast: Loadable<[CleanForecastDataPoint]> = .initial
        var gauge: GaugeRef
        var available = true
    }

    enum Action {
        case load
        case setForecast(Loadable<[CleanForecastDataPoint]>)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .setForecast(let newValue):
                state.forecast = newValue
                return .none
            case .load:
                guard state.gauge.source == .usgs else {
                    state.available = false
                    return .none
                }

                state.forecast = .loading

                return .run { [gauge = state.gauge] send in
                    do {
                        guard gauge.source == .usgs else {
                            return
                        }

                        // Configure once per run, not per data point
                        FlowForecast.CodableHelper.dateFormatter = forecastDateFormatter

                        let now = Date()
                        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!

                        let result = try await UsgsAPI.forecastUsgsForecastPost(uSGSFlowForecastRequest: .init(
                                                                                    siteId: gauge.siteID,
                                                                                    readingParameter: "00060",
                                                                                    startDate: oneYearAgo,
                                                                                    endDate: now))

                        // Use compactMap to combine transformation and filtering
                        // Reuse a single calendar for all date parsing
                        let calendar = Calendar.current
                        let year = calendar.component(.year, from: now)

                        let cleanedForecast: [CleanForecastDataPoint] = result.compactMap { value in
                            // Filter out invalid values early
                            guard
                                let forecast = value.forecast,
                                let lower = value.lowerErrorBound,
                                let upper = value.upperErrorBound,
                                forecast != 0, lower != 0, upper != 0
                            else {
                                return nil
                            }

                            // Parse date efficiently with shared calendar
                            guard let index = parseForecastDate(value.index, year: year, calendar: calendar) else {
                                return nil
                            }

                            return CleanForecastDataPoint(
                                index: index,
                                value: forecast,
                                lowerErrorBound: lower,
                                upperErrorBound: upper)
                        }

                        await send(.setForecast(.loaded(cleanedForecast)))
                    } catch {
                        logger.error("Forecast error: \(error.localizedDescription)")
                        await send(.setForecast(.error(error)))
                    }
                }
            }
        }
    }

    // MARK: Private

    private let logger = Logger(category: "GaugeFlowForecastFeature")
}

// MARK: - CleanForecastDataPoint

nonisolated struct CleanForecastDataPoint: Identifiable, Equatable, Sendable {

    init(id: UUID = UUID(), index: Date, value: Double, lowerErrorBound: Double, upperErrorBound: Double) {
        self.id = id
        self.index = index
        self.value = value
        self.lowerErrorBound = lowerErrorBound
        self.upperErrorBound = upperErrorBound
    }

    let id: UUID
    let index: Date
    let value: Double
    let lowerErrorBound: Double
    let upperErrorBound: Double
}

// Optimized to accept calendar and year as parameters to avoid repeated allocations
private nonisolated func parseForecastDate(_ index: String, year: Int, calendar: Calendar) -> Date? {
    let components = index.split(separator: "/")

    guard
        components.count == 2,
        let month = Int(components[0]),
        let day = Int(components[1])
    else {
        return nil
    }

    return calendar.date(from: DateComponents(year: year, month: month, day: day))
}

// MARK: - ForecastError

public enum ForecastError: Error {
    case failedToGetIndexDate
    case failedToGetForecast
}

// Move outside the reducer to avoid MainActor isolation
private let forecastDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()
