//
//  GaugeFlowForecastFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/28/25.
//

import ComposableArchitecture
import FlowForecast
import Foundation
import Loadable
import GaugeSources

@Reducer
struct GaugeFlowForecastFeature {
    @ObservableState
    struct State {
        var forecast: Loadable<String> = .initial
        var gauge: GaugeRef
        var available: Bool = true
    }

    enum Action {
        case load
        case setForecast(Loadable<String>)
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
                        let now = Date()
                        // one year ago
                        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!

                        let result = try await UsgsAPI.forecastUsgsForecastPost(uSGSFlowForecastRequest: .init(
                                                                                    siteId: gauge.siteID,
                                                                                    readingParameter: "00060",
                                                                                    startDate: oneYearAgo,
                                                                                    endDate: now))
                        
                        print(result)
                        await send(.setForecast(.loaded("loaded")))
                    } catch {
                        await send(.setForecast(.error(error)))
                    }
                }
            }
        }
    }
}
