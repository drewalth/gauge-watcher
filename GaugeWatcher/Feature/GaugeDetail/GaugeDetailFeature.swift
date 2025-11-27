//
//  GaugeDetailFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import Foundation
import GaugeDrivers
import GaugeSources
import Loadable
import os

// MARK: - GaugeDetailFeature

@Reducer
struct GaugeDetailFeature {

    private let logger = Logger(category: "GaugeDetailFeature")

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
        case openSource
    }

    @Dependency(\.gaugeService) var gaugeService: GaugeService
    @Dependency(\.webBrowserService) var webBrowserService: WebBrowserService

    nonisolated enum CancelID {
        case sync
        case loadReadings
        case load
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .openSource:
                return .run { [gauge = state.gauge] _ in
                    do {
                        guard
                            let gaugeRef = gauge.unwrap(),
                            let sourceURL = gaugeRef.sourceURL
                        else {
                            throw Errors.invalidGaugeSourceURL
                        }

                        try await webBrowserService.open(sourceURL, WebBrowserOptions())

                    } catch {
                        logger.error("\(#function): \(error.localizedDescription)")
                    }
                }
            case .toggleFavorite:
                guard state.gauge.unwrap() != nil else {
                    return .none
                }
                return .concatenate(
                    .run { [gaugeID = state.gaugeID] _ in
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
                // If we already have readings, show them while reloading. Otherwise, show loading.
                if state.readings.isLoaded() {
                    state.readings = .reloading(state.readings.unwrap()!)
                } else {
                    state.readings = .loading
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
                }.cancellable(id: CancelID.loadReadings, cancelInFlight: true)
            case .sync:
                guard let gauge = state.gauge.unwrap() else {
                    logger.warning("gauge not set in state")
                    return .none
                }

                state.gauge = .reloading(gauge)
                state.readings = .reloading(state.readings.unwrap() ?? [])
                return .run { [gaugeID = state.gaugeID] send in
                    do {
                        // Sync with API
                        try await gaugeService.sync(gaugeID)

                        // Reload gauge from database after sync
                        let updatedGauge = try await gaugeService.loadGauge(gaugeID).ref
                        await send(.setGauge(.loaded(updatedGauge)))

                        // Now load readings
                        await send(.loadReadings)
                    } catch {
                        await send(.setGauge(.error(error)))
                        await send(.setReadings(.error(error)))
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
                return .run { [state] send in
                    do {
                        let gauge = try await gaugeService.loadGauge(state.gaugeID).ref

                        await send(.setGauge(.loaded(gauge)))

                        if gauge.isStale() {
                            logger.info("syncing gauge")
                            await send(.sync)
                        } else {
                            // Only load readings if we're not syncing (sync will load them after)
                            await send(.loadReadings)
                        }

                    } catch {
                        await send(.setGauge(.error(error)))
                    }
                }.cancellable(id: CancelID.load, cancelInFlight: true)
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

// MARK: GaugeDetailFeature.Errors

extension GaugeDetailFeature {
    enum Errors: Error, LocalizedError {
        case invalidGaugeSourceURL

        var errorDescription: String? {
            switch self {
            case .invalidGaugeSourceURL:
                "Invalid gauge source URL"
            }
        }
    }
}
