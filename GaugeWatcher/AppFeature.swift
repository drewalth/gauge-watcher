//
//  AppFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import AppTelemetry
import ComposableArchitecture
import Foundation
import Loadable
import os
import SQLiteData

@Reducer
struct AppFeature {

    private let logger = Logger(category: "AppFeature")

    @ObservableState
    struct State {
        var initialized: Loadable<Bool>

        var selectedTab: RootTab = .favorites

        init(initialized: Loadable<Bool> = .initial) {
            self.initialized = initialized
        }

        var gaugeSearch: GaugeSearchFeature.State?
        var favorites: FavoriteGaugesFeature.State?
    }

    enum Action {
        case initialize
        case setInitialized(Loadable<Bool>)
        case setSelectedTab(RootTab)
        case gaugeSearch(GaugeSearchFeature.Action)
        case favorites(FavoriteGaugesFeature.Action)
    }

    enum RootTab {
        case search, favorites
    }

    @Dependency(\.defaultDatabase)
    var database

    @Dependency(\.gaugeService)
    var gaugeService: GaugeService

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .gaugeSearch, .favorites:
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
                return .run { send in
                    do {
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
                            // TODO: need mechanism for identifying and adding new gauge sources. It's probably best to manage and serve sources from remote rather than local JSON files.
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
        }.ifLet(\.gaugeSearch, action: \.gaugeSearch) {
            GaugeSearchFeature()
        }
        .ifLet(\.favorites, action: \.favorites) {
            FavoriteGaugesFeature()
        }
    }
}
