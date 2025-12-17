//
//  FavoritesView.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import SharedFeatures
import SwiftUI

// MARK: - FavoritesView

struct FavoritesView: View {

    // MARK: Internal

    @Bindable var store: StoreOf<FavoriteGaugesFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            content
                .navigationTitle("Favorites")
                .task {
                    store.send(.load)
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
        switch store.gauges {
        case .initial, .loading:
            ProgressView("Loading favorites...")
        case .loaded(let gauges), .reloading(let gauges):
            if gauges.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Add gauges to favorites from the map view"))
            } else {
                List {
                    ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
                        FavoriteGaugeTileView(store: rowStore)
                    }
                }
            }
        case .error(let error):
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription))
        }
    }
}

// MARK: - FavoriteGaugeTileView

struct FavoriteGaugeTileView: View {

    @Bindable var store: StoreOf<FavoriteGaugeTileFeature>

    var body: some View {
        Button {
            store.send(.goToGaugeDetail(store.gauge.id))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.gauge.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(store.gauge.source.rawValue) • \(store.gauge.state)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    FavoritesView(store: Store(initialState: FavoriteGaugesFeature.State()) {
        FavoriteGaugesFeature()
    })
}
