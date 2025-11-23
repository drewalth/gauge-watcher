//
//  GaugeDetailFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import Loadable

@Reducer
struct GaugeDetailFeature {
    @ObservableState
    struct State {
        var gauge: Loadable<GaugeRef>
    }

    enum Action {
        case load
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .load:
                return .none
            }
        }
    }
}
