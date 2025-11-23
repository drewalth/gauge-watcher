//
//  GaugeSearchFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import ComposableArchitecture
import Loadable
import SQLiteData

@Reducer
struct GaugeSearchFeature {
    @ObservableState
    struct State {
        var queryString = ""
        var results: Loadable<[GaugeRef]> = .initial
    }

    enum Action {
        case query
        case setResults(Loadable<[GaugeRef]>)
        case setQueryString(String)
    }

    @Dependency(\.defaultDatabase) var database

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .setQueryString(let newValue):
                state.queryString = newValue
                return .none
            case .query:
                state.results = .loading
                return .run { [queryString = state.queryString] send in
                    do {
                        let results = try await database.read { db in
                            if !queryString.isEmpty {
                                return try Gauge
                                    .where { $0.name.lower().contains(queryString.lowercased()) }
                                    .order(by: \.name)
                                    .fetchAll(db)

                                    .map { $0.ref }
                            } else {
                                return try Gauge.all
                                    .order(by: \.name)
                                    .fetchAll(db)
                                    .map { $0.ref }
                            }
                        }
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
