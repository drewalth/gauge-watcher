//
//  GaugeSearch.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import ComposableArchitecture
import SwiftUI
import Loadable

struct GaugeSearch: View {
    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        NavigationStack {
            content()
                .task {
                    store.send(.initialize)
                }
        }
    }
    
    @ViewBuilder
    private func content() -> some View {
        switch store.initialized {
        case .initial, .loading:
            ProgressView()
        case .loaded(let isInitialized), .reloading(let isInitialized):
            if isInitialized {
                Group {
                    if store.mode == .list {
                        GaugeSearchList(store: store)
                    } else {
                        GaugeSearchMap(store: store)
                    }
                }
            } else {
                ProgressView()
            }
        case .error(let error):
            Text(error.localizedDescription)
        }
    }
}
