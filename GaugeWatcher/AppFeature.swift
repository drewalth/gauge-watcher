//
//  AppFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

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
        @Shared(.appStorage(LocalStorageKey.gaugesSeeded.rawValue)) var gaugesSeeded = false

        var selectedTab: RootTab = .search
        
        init(initialized: Loadable<Bool> = .initial) {
            self.initialized = initialized
        }
        
        var gaugeSearch: GaugeSearchFeature.State?
        var favorites: FavoriteGaugesFeature.State?
    }

    enum Action {
        case initialize
        case setInitialized(Loadable<Bool>)
        case setGaugesSeeded(Bool)
        case setSelectedTab(RootTab)
        case gaugeSearch(GaugeSearchFeature.Action)
        case favorites(FavoriteGaugesFeature.Action)
    }
    
    enum RootTab {
        case search, favorites
    }

    @Dependency(\.defaultDatabase)
    var database

    @Dependency(\.gaugeSourceService) var gaugeSourceService: GaugeSourceService

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
                return .none
            case .setGaugesSeeded(let newValue):
                state.$gaugesSeeded.withLock { $0 = newValue }
                return .none
            case .initialize:
                // TODO: update this so that we can easily add new gauge sources and update existing gauge sources
                guard !state.gaugesSeeded else {
                    state.initialized = .loaded(true)
                    state.gaugeSearch = GaugeSearchFeature.State()
                    state.favorites = FavoriteGaugesFeature.State()
                    return .none
                }
                state.initialized = .loading
                return .run { send in
                    do {
                        // Load gauge data asynchronously
                        let gaugeData = try await gaugeSourceService.loadAll()

                        try await Task { @MainActor in
                            try database.write { db in
                                try db.seedGaugeData(gaugeData)
                            }
                        }.value

                        await send(.setGaugesSeeded(true))
                        await send(.setInitialized(.loaded(true)))
                    } catch {
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
