//
//  GaugeSearchList.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import Loadable
import SwiftUI

struct GaugeSearchList: View {
    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        List {
            switch store.results {
            case .loading, .initial:
                ProgressView()
            case .loaded(let gauges), .reloading(let gauges):
                ForEach(gauges, id: \.id) { gauge in
                    Text(gauge.name)
                        .onTapGesture {
                            store.send(.goToGaugeDetail(gauge.id))
                        }
                }
            case .error(let err):
                Text(String(describing: err.localizedDescription))
            }
        }.gaugeWatcherList()
        .searchable(text: Binding<String>(
                        get: {
                            store.queryOptions.name ?? ""
                        },
                        set: { newValue in
                            store.send(.setSearchText(newValue))
                        }))
        .navigationTitle("Gauges")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.toggleMode)
                } label: {
                    Label("Mode", systemImage: store.mode == .list ? "list.bullet" : "map")
                        .labelStyle(.iconOnly)
                }
            }
        }
    }
}
