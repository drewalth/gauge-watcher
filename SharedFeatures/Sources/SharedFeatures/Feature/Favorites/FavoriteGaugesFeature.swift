//
//  FavoriteGaugesFeature.swift
//  SharedFeatures
//

import ComposableArchitecture
import Foundation
import GaugeService
import Loadable

// MARK: - FavoriteGaugesFeature

@Reducer
public struct FavoriteGaugesFeature: Sendable {

  // MARK: Lifecycle

  // MARK: - Dependencies


  // MARK: - Initializer

  public init() { }

  // MARK: Public

  // MARK: - State

  @ObservableState
  public struct State {
    public var gauges: Loadable<[GaugeRef]> = .initial
    public var rows: IdentifiedArrayOf<FavoriteGaugeTileFeature.State> = []
    public var path = StackState<Path.State>()

    public init(
      gauges: Loadable<[GaugeRef]> = .initial,
      rows: IdentifiedArrayOf<FavoriteGaugeTileFeature.State> = [],
      path: StackState<Path.State> = .init())
    {
      self.gauges = gauges
      self.rows = rows
      self.path = path
    }
  }

  // MARK: - Action

  public enum Action {
    case load
    case setRows(IdentifiedArrayOf<FavoriteGaugeTileFeature.State>)
    case setGauges(Loadable<[GaugeRef]>)
    case path(StackActionOf<Path>)
    indirect case rows(IdentifiedActionOf<FavoriteGaugeTileFeature>)
  }

  // MARK: - Path

  @Reducer
  public enum Path {
    case gaugeDetail(GaugeDetailFeature)
  }

  // MARK: - Body

  public var body: some Reducer<State, Action> {
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

      case .path:
        return .none

      case .load:
        if state.gauges.isInitial() || state.gauges.isError() {
          state.gauges = .loading
        } else {
          state.gauges = .reloading(state.gauges.unwrap() ?? [])
        }
        return .run { send in
          do {
            @Dependency(\.gaugeService) var gaugeService: GaugeService

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
    }
    .forEach(\.path, action: \.path)
    .forEach(\.rows, action: \.rows) {
      FavoriteGaugeTileFeature()
    }
  }
}

