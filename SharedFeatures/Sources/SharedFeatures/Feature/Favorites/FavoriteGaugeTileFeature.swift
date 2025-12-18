//
//  FavoriteGaugeTileFeature.swift
//  SharedFeatures
//

import ComposableArchitecture
import Foundation
import GaugeService
import Loadable

// MARK: - FavoriteGaugeTileFeature

@Reducer
public struct FavoriteGaugeTileFeature: Sendable {

    // MARK: Lifecycle

    // MARK: - Initializer

    public init() { }

    // MARK: Public

    // MARK: - State

    @ObservableState
    public struct State: Identifiable, Equatable, Sendable {
        public let id: UUID
        public var gauge: GaugeRef
        public var readings: Loadable<[GaugeReadingRef]> = .initial

        public init(_ gauge: GaugeRef, id: UUID? = nil) {
            self.gauge = gauge
            @Dependency(\.uuid) var uuid
            self.id = id ?? uuid()
        }
    }

    // MARK: - Action

    public enum Action {
        case loadReadings
        case setReadings(Loadable<[GaugeReadingRef]>)
        case goToGaugeDetail(Int)
        case sync
    }

    // MARK: - CancelID

    nonisolated public enum CancelID: Sendable {
        case loadReadings
        case sync
    }

    // MARK: - Body

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .sync:
                return .run { [gauge = state.gauge] send in
                    do {
                        guard gauge.isStale() else {
                            return
                        }
                        @Dependency(\.gaugeService) var gaugeService
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
                        @Dependency(\.gaugeService) var gaugeService
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
