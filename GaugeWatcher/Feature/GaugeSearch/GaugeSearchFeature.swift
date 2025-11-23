//
//  GaugeSearchFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import ComposableArchitecture
import Loadable
import os
import SQLiteData

@Reducer
struct GaugeSearchFeature {

    private let logger = Logger(category: "GaugeSearchFeature")

    @ObservableState
    struct State {
        var queryString = ""
        var results: Loadable<[GaugeRef]> = .initial
        var queryOptions = GaugeQueryOptions()
    }

    enum Action {
        case query
        case setResults(Loadable<[GaugeRef]>)
        case setQueryString(String)
    }

    @Dependency(\.databaseService) var databaseService: DatabaseService

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .setQueryString(let newValue):
                state.queryString = newValue
                return .none
            case .query:
                state.results = .loading
                return .run { [state] send in
                    do {
                        let results = try await databaseService.loadGauges(state.queryOptions).map { $0.ref }
                        await send(.setResults(.loaded(results)))
                    } catch {
                        await send(.setResults(.error(error)))
                    }
                }
            case .setResults(let results):
                state.results = results
                return .none
            }
        }
    }
}
