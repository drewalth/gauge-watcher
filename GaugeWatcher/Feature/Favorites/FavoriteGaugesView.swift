//
//  FavoriteGaugesView.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import SwiftUI
import ComposableArchitecture
import Loadable
import SwiftUI

struct FavoriteGaugesView: View {
    @Bindable var store: StoreOf<FavoriteGaugesFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List {
                switch store.gauges {
                case .loading, .initial:
                    ProgressView()
                case .loaded(let gauges), .reloading(let gauges):
                    ForEach(gauges, id: \.id) { gauge in
                        Text(gauge.name)
                            .onTapGesture {
                                store.send(.goToGaugeDetail(gauge.id))
                            }
                    }
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
}
