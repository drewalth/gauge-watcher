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

        init(_ gaugeID: Int) {
            self.gaugeID = gaugeID
        }
    }

    enum Action {
        case load
        case setGauge(Loadable<GaugeRef>)
        case sync
    }

    @Dependency(\.gaugeService) var gaugeService: GaugeService

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .sync:
                guard let gauge = state.gauge.unwrap() else {
                    return .none
                }

                state.gauge = .reloading(gauge)
                return .none
            case .setGauge(let newValue):
                state.gauge = newValue
                return .none
            case .load:
                guard state.gauge.isInitial() else {
                    return .none
                }

                state.gauge = .loading
                return .run { [state] send in
                    do {
                        let gauge = try await gaugeService.loadGauge(state.gaugeID).ref

                        await send(.setGauge(.loaded(gauge)))

                    } catch {
                        await send(.setGauge(.error(error)))
                    }
                }
            }
        }
    }
}
