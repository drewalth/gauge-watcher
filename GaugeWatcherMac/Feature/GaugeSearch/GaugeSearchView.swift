//
//  GaugeSearchView.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import SharedFeatures
import SwiftUI

// MARK: - GaugeSearchView

struct GaugeSearchView: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            content
                .task {
                    store.send(.initialize)
                }
        } destination: { store in
            switch store.case {
            case .gaugeDetail(let gaugeDetailStore):
                GaugeDetail(store: gaugeDetailStore)
            }
        }
    }

    // MARK: Private

    @ViewBuilder
    private var content: some View {
        switch store.initialized {
        case .initial, .loading:
            ProgressView("Loading gauges...")
        case .loaded(let isInitialized), .reloading(let isInitialized):
            if isInitialized {
                GaugeSearchMap(store: store)
            } else {
                errorView("Failed to load map")
            }
        case .error(let error):
            errorView(error.localizedDescription)
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView(
            "Error",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
    }
}

// MARK: - Preview

#Preview {
    GaugeSearchView(store: Store(initialState: GaugeSearchFeature.State()) {
        GaugeSearchFeature()
    })
}

