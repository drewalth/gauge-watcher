//
//  GaugeDetail.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import Loadable
import SwiftUI

struct GaugeDetail: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        List {
            content()
        }.gaugeWatcherList()
        .task {
            store.send(.load)
        }.toolbar {
            ToolbarItem(placement: .primaryAction) {
                GaugeFavoriteToggle(onPress: {
                    store.send(.toggleFavorite)
                }, isFavorite: store.gauge.unwrap()?.favorite ?? false)
            }
        }
    }

    // MARK: Private

    @ViewBuilder
    private func content() -> some View {
        switch store.gauge {
        case .initial, .loading:
            ProgressView()
        case .loaded(let gauge), .reloading(let gauge):
            Text(gauge.name)
            GaugeReadingChart(store: store)
        case .error(let error):
            Text(error.localizedDescription)
        }
    }
}
