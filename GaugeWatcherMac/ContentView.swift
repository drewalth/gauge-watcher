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

    @State private var showInspector = true
    @State private var inspectorMode: InspectorMode = .nearby

    @ViewBuilder
    private var mainContent: some View {
        if let gaugeSearchStore = store.scope(state: \.gaugeSearch, action: \.gaugeSearch) {
            GaugeSearchView(store: gaugeSearchStore)
                .ignoresSafeArea(.container, edges: .all)
                .inspector(isPresented: $showInspector) {
                    GaugeListInspector(
                        gaugeSearchStore: gaugeSearchStore,
                        favoritesStore: store.scope(state: \.favorites, action: \.favorites),
                        mode: $inspectorMode)
                        .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        inspectorModeToggle
                        Button("Toggle Inspector", systemImage: "sidebar.trailing") {
                            showInspector.toggle()
                        }
                        .keyboardShortcut("i", modifiers: [.command, .option])
                    }
                }
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private var inspectorModeToggle: some View {
        Picker("Mode", selection: $inspectorMode) {
            Label("Nearby", systemImage: "map")
                .tag(InspectorMode.nearby)
            Label("Favorites", systemImage: "star")
                .tag(InspectorMode.favorites)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView(
            "Error",
            systemImage: "exclamationmark.triangle",
            description: Text(message))
    }
}

// MARK: - InspectorMode

enum InspectorMode: Hashable {
    case nearby
    case favorites
}

// MARK: - Preview

#Preview {
    ContentView(store: Store(initialState: AppFeature.State()) {
        AppFeature()
    })
}
