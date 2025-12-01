//
//  FavoriteGaugesView.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import ComposableArchitecture
import Loadable
import SwiftUI
import UIComponents

struct FavoriteGaugesView: View {

    // MARK: Internal

    @Bindable var store: StoreOf<FavoriteGaugesFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List {
                switch store.gauges {
                case .loading, .initial:
                    ContinuousSpinner()
                case .loaded(let gauges), .reloading(let gauges):
                    listContent(gauges)
                case .error(let error):
                    Text(error.localizedDescription)
                }
            }.gaugeWatcherList()
            .onAppear {
                store.send(.load)
            }
            .navigationTitle("Favorites")
        } destination: { store in
            switch store.case {
            case .gaugeDetail(let gaugeDetailStore):
                GaugeDetail(store: gaugeDetailStore)
            }
        }
    }

    // MARK: Private

    @ViewBuilder
    private func listContent(_ gauges: [GaugeRef]) -> some View {
        if gauges.count == 0 {
            UtilityBlockView(title: "No favorites", kind: .empty)
                .listRowBackground(Color.clear)
        } else {
            ForEach(gauges, id: \.id) { gauge in
                Text(gauge.name)
                    .onTapGesture {
                        store.send(.goToGaugeDetail(gauge.id))
                    }
            }
        }
    }
}
