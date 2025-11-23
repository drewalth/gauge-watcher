//
//  AppFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import Loadable
import os
import SQLiteData
import Foundation

@Reducer
struct AppFeature {
    
    private let logger = Logger(category: "AppFeature")
    
    @ObservableState
    struct State {
        var initialized: Loadable<Bool>
        @Shared(.appStorage(LocalStorageKey.gaugesSeeded.rawValue)) var gaugesSeeded: Bool = false
        
        init(initialized: Loadable<Bool> = .initial) {
            self.initialized = initialized
        }
    }
    
    enum Action {
        case initialize
        case setInitialized(Loadable<Bool>)
        case setGaugesSeeded(Bool)
    }
    
    @Dependency(\.defaultDatabase)
    var database
    
    @Dependency(\.gaugeSourceService) var gaugeSourceService: GaugeSourceService
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .setInitialized(let newValue):
                state.initialized = newValue
                return .none
            case .setGaugesSeeded(let newValue):
                state.$gaugesSeeded.withLock {  $0 = newValue }
                return .none
            case .initialize:
                // TODO: update this so that we can easily add new gauge sources and update existing gauge sources
                guard !state.gaugesSeeded else {
                    state.initialized = .loaded(true)
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
        }
    }
}
