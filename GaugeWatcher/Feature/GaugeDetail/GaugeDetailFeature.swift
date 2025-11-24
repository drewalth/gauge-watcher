//
//  GaugeDetailFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import GaugeDrivers
import GaugeSources
import Loadable
import os

@Reducer
struct GaugeDetailFeature {

    private let logger = Logger(category: "")

    @ObservableState
    struct State {
        var gaugeID: Int
        var gauge: Loadable<GaugeRef> = .initial
        var readings: Loadable<[GaugeReadingRef]> = .initial
        var selectedTimePeriod: TimePeriod.PredefinedPeriod = .last7Days
        var availableMetrics: [GaugeSourceMetric]?
        var selectedMetric: GaugeSourceMetric?

        init(_ gaugeID: Int) {
            self.gaugeID = gaugeID
        }
    }

    enum Action {
        case load
        case setGauge(Loadable<GaugeRef>)
        case sync
        case loadReadings
        case setReadings(Loadable<[GaugeReadingRef]>)
        case setSelectedTimePeriod(TimePeriod.PredefinedPeriod)
        case setAvailableMetrics([GaugeSourceMetric])
        case setSelectedMetric(GaugeSourceMetric)
        case toggleFavorite
    }

    @Dependency(\.gaugeService) var gaugeService: GaugeService

    nonisolated enum CancelID {
        case sync
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .toggleFavorite:
                guard let gauge = state.gauge.unwrap() else {
                    return .none
                }
                return .concatenate(
                    .run { [gaugeID = state.gaugeID] send in
                    try await gaugeService.toggleFavorite(gaugeID)
                }, .send(.load))
            case .setAvailableMetrics(let newValue):
                state.availableMetrics = newValue
                return .none
            case .setSelectedMetric(let newValue):
                state.selectedMetric = newValue
                return .none
            case .setSelectedTimePeriod(let newValue):
                state.selectedTimePeriod = newValue
                return .none
            case .setReadings(let newValue):
                state.readings = newValue
                return .none
            case .loadReadings:
                if state.readings.isInitial() || state.readings.isError() {
                    state.readings = .loading
                } else {
                    state.readings = .reloading(state.readings.unwrap() ?? [])
                }

                return .run { [gaugeID = state.gaugeID] send in
                    do {
                        let readings = try await gaugeService.loadGaugeReadings(.init(gaugeID: gaugeID)).map { $0.ref }
                        let availableMetrics = getAvailableMetrics(for: readings)

                        await send(.setAvailableMetrics(availableMetrics))
                        if let selectedMetric = availableMetrics.first {
                            await send(.setSelectedMetric(selectedMetric))
                        }
                        await Task.yield()
                        await send(.setReadings(.loaded(readings)))

                    } catch {
                        await send(.setReadings(.error(error)))
                    }
                }
            case .sync:
                guard let gauge = state.gauge.unwrap() else {
                    return .none
                }

                state.gauge = .reloading(gauge)
                return .run { [gaugeID = state.gaugeID] send in
                    do {
                        try await gaugeService.sync(gaugeID)
                        await send(.loadReadings)
                    } catch {
                        await send(.setGauge(.error(error)))
                    }
                }.cancellable(id: CancelID.sync, cancelInFlight: false)
            case .setGauge(let newValue):
                state.gauge = newValue
                return .none
            case .load:
                if state.gauge.isLoaded() {
                    state.gauge = .reloading(state.gauge.unwrap()!)
                } else if state.gauge.isInitial() {
                    state.gauge = .loading
                }
                return .concatenate(.run { [state] send in
                    do {
                        let gauge = try await gaugeService.loadGauge(state.gaugeID).ref

                        await send(.setGauge(.loaded(gauge)))

                        if !gauge.isStale() {
                            logger.info("Gauge not stale. Skipping sync.")
                            return
                        }
                        await send(.sync)
                    } catch {
                        await send(.setGauge(.error(error)))
                    }
                }, .send(.loadReadings))
            }
        }
    }

    private nonisolated func getAvailableMetrics(for readings: [GaugeReadingRef]) -> [GaugeSourceMetric] {
        // Use Set to get unique metrics, then convert back to array
        // TODO: usage of .uppercased() here is a design flaw
        let uniqueMetrics = Set(readings.compactMap { GaugeSourceMetric(rawValue: $0.metric.uppercased()) })
        return Array(uniqueMetrics).sorted { $0.rawValue < $1.rawValue }
    }
}
