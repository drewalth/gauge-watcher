//
//  GaugeDetailFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
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
    }

    @Dependency(\.gaugeService) var gaugeService: GaugeService

    nonisolated enum CancelID {
        case sync
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
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
                guard state.gauge.isInitial() else {
                    return .none
                }

                state.gauge = .loading
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
}
