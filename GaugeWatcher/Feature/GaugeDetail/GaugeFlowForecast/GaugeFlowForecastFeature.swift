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
                        // intentional redundant check
                        guard gauge.source == .usgs else {
                            return
                        }

                        // Configure the SDK to use date-only formatting (yyyy-MM-dd)
                        // The Python API expects date format, not ISO8601 datetime
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        dateFormatter.calendar = Calendar(identifier: .iso8601)
                        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                        FlowForecast.CodableHelper.dateFormatter = dateFormatter

                        let now = Date()
                        // one year ago
                        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!

                        let result = try await UsgsAPI.forecastUsgsForecastPost(uSGSFlowForecastRequest: .init(
                                                                                    siteId: gauge.siteID,
                                                                                    readingParameter: "00060",
                                                                                    startDate: oneYearAgo,
                                                                                    endDate: now))

                        await Task.yield()
                        let cleanedForecast = try result.map { value in
                            let index = try getDateFromForecastIndex(index: value.index)
                            return CleanForecastDataPoint(
                                index: index,
                                value: value.forecast ?? 0,
                                lowerErrorBound: value.lowerErrorBound ?? 0,
                                upperErrorBound: value.upperErrorBound ?? 0)
                        }.filter { $0.value != 0 && $0.lowerErrorBound != 0 && $0.upperErrorBound != 0 }
                        
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

private nonisolated func getDateFromForecastIndex(index: String) throws -> Date {
    // index string is 8/28.
    // where 8 is the month and 28 is the day

    let components = index.split(separator: "/")

    guard let month = Int(components[0]) else {
        throw ForecastError.failedToGetIndexDate
    }

    guard let day = Int(components[1]) else {
        throw ForecastError.failedToGetIndexDate
    }

    let calendar = Calendar.current

    let year = calendar.component(.year, from: Date())

    var dateComponents = DateComponents()

    dateComponents.year = year

    dateComponents.month = month

    dateComponents.day = day

    guard let date = calendar.date(from: dateComponents) else {
        throw ForecastError.failedToGetIndexDate
    }

    return date
}

// MARK: - ForecastError

public enum ForecastError: Error {
    case failedToGetIndexDate
    case failedToGetForecast
}
