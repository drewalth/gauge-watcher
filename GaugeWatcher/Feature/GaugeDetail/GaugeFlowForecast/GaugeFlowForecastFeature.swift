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
import GaugeDrivers

// MARK: - GaugeFlowForecastFeature

@Reducer
struct GaugeFlowForecastFeature {

    // MARK: Internal

    @ObservableState
    struct State {
        var forecast: Loadable<[ForecastDataPoint]> = .initial
        var gauge: GaugeRef
        var available = true
    }

    enum Action {
        case load
        case setForecast(Loadable<[ForecastDataPoint]>)
    }
    
    @Dependency(\.gaugeService) var gaugeService: GaugeService

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

                        let result = try await gaugeService.forecast(gauge.siteID, USGS.USGSParameter.discharge)

                        await send(.setForecast(.loaded(result)))
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
