//
//  FavoriteGaugesFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import ComposableArchitecture
import Loadable
import SwiftUI

// MARK: - FavoriteGaugesFeature

@Reducer
struct FavoriteGaugesFeature {

    @ObservableState
    struct State {
        var gauges: Loadable<[GaugeRef]> = .initial
        var rows: IdentifiedArrayOf<FavoriteGaugeTileFeature.State> = []
        var path = StackState<Path.State>()
    }

    enum Action {
        case load
        case setRows(IdentifiedArrayOf<FavoriteGaugeTileFeature.State>)
        case setGauges(Loadable<[GaugeRef]>)
        case path(StackActionOf<Path>)
        indirect case rows(IdentifiedActionOf<FavoriteGaugeTileFeature>)
    }

    @Reducer
    enum Path {
        case gaugeDetail(GaugeDetailFeature)
    }

    @Dependency(\.gaugeService) var gaugeService: GaugeService

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .rows(let rowAction):
                switch rowAction {
                case .element(id: _, action: .goToGaugeDetail(let gaugeID)):
                    state.path.append(.gaugeDetail(GaugeDetailFeature.State(gaugeID)))
                    return .none
                default:
                    return .none
                }
            case .setRows(let newValue):
                state.rows = newValue
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

                        await send(.setRows(IdentifiedArray(uniqueElements: gauges.map { FavoriteGaugeTileFeature.State($0) })))
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
        .forEach(\.rows, action: \.rows) {
            FavoriteGaugeTileFeature()
        }
    }
}

// MARK: - FavoriteGaugeTileFeature

@Reducer
struct FavoriteGaugeTileFeature {
    @ObservableState
    nonisolated struct State: Identifiable, Equatable, Sendable {
        let id: UUID
        var gauge: GaugeRef
        var readings: Loadable<[GaugeReadingRef]> = .initial

        init(_ gauge: GaugeRef, id: UUID? = nil) {
            self.gauge = gauge
            @Dependency(\.uuid) var uuid
            self.id = id ?? uuid()
        }
    }

    enum Action {
        case loadReadings
        case setReadings(Loadable<[GaugeReadingRef]>)
        case goToGaugeDetail(Int)
        case sync
    }

    nonisolated enum CancelID {
        case loadReadings
        case sync
    }

    @Dependency(\.gaugeService) var gaugeService: GaugeService

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .sync:
                return .run { [gauge = state.gauge] send in
                    do {
                        guard gauge.isStale() else {
                            return
                        }
                        try await gaugeService.sync(gauge.id)
                        await send(.loadReadings)
                    } catch {
                        await send(.setReadings(.error(error)))
                    }
                }.cancellable(id: CancelID.sync, cancelInFlight: true)
            case .goToGaugeDetail:
                return .none
            case .loadReadings:
                if state.readings.isLoaded() {
                    state.readings = .reloading(state.readings.unwrap()!)
                } else {
                    state.readings = .loading
                }
                return .run { [gauge = state.gauge] send in
                    do {
                        let readings = try await gaugeService.loadGaugeReadings(.init(gaugeID: gauge.id)).map { $0.ref }
                        await send(.setReadings(.loaded(readings)))
                    } catch {
                        await send(.setReadings(.error(error)))
                    }
                }.concatenate(with: .send(.sync))
                .cancellable(id: CancelID.loadReadings, cancelInFlight: true)

            case .setReadings(let newValue):
                state.readings = newValue
                return .none
            }
        }
    }
}
