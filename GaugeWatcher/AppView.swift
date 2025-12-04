//
//  App.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//

import AppTelemetry
import ComposableArchitecture
import Loadable
import SwiftUI
import UIComponents

// MARK: - AppView

struct AppView: View {

    // MARK: Internal

    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            content()
        }.trackView("AppView")
        .task {
            store.send(.initialize)
        }
    }

    // MARK: Private

    @ViewBuilder
    private func content() -> some View {
        switch store.initialized {
        case .initial, .reloading, .loading:
            ContinuousSpinner()
        case .error:
            UtilityBlockView(kind: .error("Something went wrong"))
        case .loaded(let isInitialized):
            if isInitialized {
                TabView(selection: $store.selectedTab.sending(\.setSelectedTab)) {
                    Group {
                        if let gaugeSearchStore = store.scope(state: \.gaugeSearch, action: \.gaugeSearch) {
                            GaugeSearch(store: gaugeSearchStore)
                        } else {
                            ContinuousSpinner()
                        }
                    }
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(0)

                    Group {
                        if let favoriteGaugesStore = store.scope(state: \.favorites, action: \.favorites) {
                            FavoriteGaugesView(store: favoriteGaugesStore)
                        } else {
                            ContinuousSpinner()
                        }
                    }
                    .tabItem {
                        Label("Favorites", systemImage: "star.fill")
                    }
                    .tag(1)
                }
            } else {
                UtilityBlockView(kind: .error("Something went wrong"))
            }
        }
    }
}
