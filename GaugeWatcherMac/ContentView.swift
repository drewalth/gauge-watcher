//
//  ContentView.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/16/25.
//

import SharedFeatures
import SwiftUI

// MARK: - ContentView

struct ContentView: View {

    // MARK: Internal

    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            switch store.initialized {
            case .initial, .loading:
                ProgressView("Loading...")
                    .task {
                        store.send(.initialize)
                    }
            case .reloading:
                mainContent
                    .overlay {
                        ProgressView()
                    }
            case .loaded(let isInitialized):
                if isInitialized {
                    mainContent
                } else {
                    errorView("Failed to initialize")
                }
            case .error(let error):
                errorView(error.localizedDescription)
            }
        }
    }

    // MARK: Private

    @State private var selectedSidebarItem: SidebarItem? = .map
    @State private var preferredColumn: NavigationSplitViewColumn = .detail
    @ViewBuilder
    private var mainContent: some View {
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            List(selection: $selectedSidebarItem) {
                Label("Map", systemImage: "map")
                    .tag(SidebarItem.map)
                Label("Favorites", systemImage: "star")
                    .tag(SidebarItem.favorites)
            }
            .navigationTitle("Gauge Watcher")
        } detail: {
            detailContent
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSidebarItem {
        case .map, .none:
            if let gaugeSearchStore = store.scope(state: \.gaugeSearch, action: \.gaugeSearch) {
                GaugeSearchView(store: gaugeSearchStore)
                .ignoresSafeArea(.container, edges: .all)
            } else {
                ProgressView()
            }
        case .favorites:
            if let favoritesStore = store.scope(state: \.favorites, action: \.favorites) {
                FavoritesView(store: favoritesStore)
            } else {
                Text("Favorites")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView(
            "Error",
            systemImage: "exclamationmark.triangle",
            description: Text(message))
    }
}

// MARK: - SidebarItem

private enum SidebarItem: Hashable {
    case map
    case favorites
}

// MARK: - Preview

#Preview {
    ContentView(store: Store(initialState: AppFeature.State()) {
        AppFeature()
    })
}
