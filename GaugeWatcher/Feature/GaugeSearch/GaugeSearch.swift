//
//  GaugeSearch.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import AppTelemetry
import ComposableArchitecture
import Loadable
import SwiftUI
import UIComponents

struct GaugeSearch: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            Group {
                content()
            }
            .trackView("GaugeSearch")
        } destination: { store in
            switch store.case {
            case .gaugeDetail(let gaugeDetailStore):
                GaugeDetail(store: gaugeDetailStore)
            }
        }
    }

    // MARK: Private

    @ViewBuilder
    private func content() -> some View {
        switch store.initialized {
        case .initial, .loading:
            ContinuousSpinner()
                .task {
                    store.send(.initialize)
                }
        case .loaded(let isInitialized), .reloading(let isInitialized):
            if isInitialized {
                GaugeSearchMap(store: store)
            } else {
                ContinuousSpinner()
            }
        case .error(let error):
            UtilityBlockView(kind: .error(error.localizedDescription))
        }
    }
}
