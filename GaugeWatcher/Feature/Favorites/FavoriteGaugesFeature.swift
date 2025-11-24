//
//  FavoriteGaugesFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import ComposableArchitecture
import Loadable
import SwiftUI

@Reducer
struct FavoriteGaugesFeature {

    @ObservableState
    struct State {
        var gauges: Loadable<[GaugeRef]> = .initial
        var path = StackState<Path.State>()
    }

    enum Action {
        case load
        case setGauges(Loadable<[GaugeRef]>)
        case path(StackActionOf<Path>)
        case goToGaugeDetail(Int)
    }

    @Dependency(\.gaugeService) var gaugeService: GaugeService
    
    @Reducer
    enum Path {
        case gaugeDetail(GaugeDetailFeature)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .goToGaugeDetail(let gaugeID):
                state.path.append(.gaugeDetail(GaugeDetailFeature.State(gaugeID)))
                return .none
            case .path(let action):
                print(action)
                return .none
            case .load:
                if state.gauges.isInitial() || state.gauges.isError() {
                    state.gauges = .loading
                } else {
                    state.gauges = .reloading(state.gauges.unwrap() ?? [])
                }
                return .run { send in
                    do {
                        let gauges = try await gaugeService.loadFavoriteGauges().map { $0.ref }
                            await send(.setGauges(.loaded(gauges)))
                    } catch {
                        await send(.setGauges(.error(error)))
                    }
                }
            case .setGauges(let newValue):
                state.gauges = newValue
                return .none
            }
        }.forEach(\.path, action: \.path)
    }
}
