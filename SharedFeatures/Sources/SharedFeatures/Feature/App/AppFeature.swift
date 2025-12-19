//
//  AppFeature.swift
//  SharedFeatures
//

import AppDatabase
import AppTelemetry
import ComposableArchitecture
import Foundation
import GaugeService
import Loadable
import os
import SQLiteData

// MARK: - AppFeature

@Reducer
public struct AppFeature: Sendable {

    // MARK: Lifecycle

    // MARK: - Initializer

    public init() { }

    // MARK: Public

    // MARK: - State

    @ObservableState
    public struct State {
        public var initialized: Loadable<Bool>
        public var selectedTab: RootTab = .search
        public var gaugeSearch: GaugeSearchFeature.State?
        public var favorites: FavoriteGaugesFeature.State?
        public var gaugeBot = GaugeBotReducer.State()

        public init(initialized: Loadable<Bool> = .initial) {
            self.initialized = initialized
        }
    }

    // MARK: - Action

    public enum Action {
        case initialize
        case setInitialized(Loadable<Bool>)
        case setSelectedTab(RootTab)
        case gaugeSearch(GaugeSearchFeature.Action)
        case favorites(FavoriteGaugesFeature.Action)
        case gaugeBot(GaugeBotReducer.Action)
    }

    // MARK: - RootTab

    public enum RootTab: Sendable {
        case search, favorites
    }

    // MARK: - Body

    public var body: some Reducer<State, Action> {
        
        Scope(state: \.gaugeBot, action: \.gaugeBot) {
            GaugeBotReducer()
        }
        
        Reduce { state, action in
            switch action {
            case .gaugeSearch, .favorites, .gaugeBot:
                return .none

            case .setSelectedTab(let newValue):
                state.selectedTab = newValue
                return .none

            case .setInitialized(let newValue):
                state.initialized = newValue
                if
                    let isInitialized = newValue.unwrap(),
                    isInitialized == true {
                    state.gaugeSearch = GaugeSearchFeature.State()
                    state.favorites = FavoriteGaugesFeature.State()
                }
                return .none

            case .initialize:
                state.initialized = .loading
                return .run { [logger] send in
                    do {
                        @Dependency(\.gaugeService) var gaugeService
                        @Dependency(\.defaultDatabase) var database

                        let isSeededResult = try await gaugeService.seeded().get()

                        if !isSeededResult {
                            let gaugeData = try await gaugeService.loadAllSources()

                            try await Task { @MainActor in
                                try database.write { db in
                                    try db.seedGaugeData(gaugeData)
                                }
                            }.value
                        } else {
                            logger.info("Gauges have already been seeded in database")
                            // TODO: need mechanism for identifying and adding new gauge sources
                        }

                        await send(.setInitialized(.loaded(true)))
                    } catch {
                        AppTelemetry.captureEvent(error.localizedDescription)
                        // Log error but don't crash the app
                        logger.error("Failed to seed database: \(error.localizedDescription)")
                        await send(.setInitialized(.error(error)))
                    }
                }
            }
        }
        .ifLet(\.gaugeSearch, action: \.gaugeSearch) {
            GaugeSearchFeature()
        }
        .ifLet(\.favorites, action: \.favorites) {
            FavoriteGaugesFeature()
        }
    }

    // MARK: Private

    private let logger = Logger(category: "AppFeature")

}
