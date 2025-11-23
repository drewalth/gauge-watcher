//
//  GaugeSearch.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import ComposableArchitecture
import Loadable
import SwiftUI

struct GaugeSearch: View {
    var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        NavigationStack {
            List {
                switch store.results {
                case .loading, .initial:
                    ProgressView()
                case .loaded(let gauges), .reloading(let gauges):
                    ForEach(gauges, id: \.id) { gauge in
                        Text(gauge.name)
                    }
                case .error(let err):
                    Text(String(describing: err.localizedDescription))
                }
            }.gaugeWatcherList()
            .task {
                store.send(.query)
            }
        }.navigationTitle("Gauges")
    }
}
