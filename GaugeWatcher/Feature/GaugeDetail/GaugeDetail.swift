//
//  GaugeDetail.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import Loadable
import SwiftUI
import UIAppearance

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
        case .loaded(let gauge):
            gaugeContent(gauge)
        case .reloading(let gauge):
            gaugeContent(gauge, reloading: true)
        case .error(let error):
            Text(error.localizedDescription)
        }
    }

    @ViewBuilder
    private func gaugeContent(_ gauge: GaugeRef, reloading: Bool = false) -> some View {
        HStack {
            Text(gauge.name)
                .font(.headline)
            Spacer()
            if reloading {
                ProgressView()
            }
        }
        GaugeReadingChart(store: store)
        LatestGaugeReading(store: store)
        if gauge.sourceURL != nil {
            Button("Source") {
                store.send(.openSource)
            }.buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
        }
    }
}
