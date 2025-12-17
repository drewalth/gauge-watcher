//
//  GaugeListInspector.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import SharedFeatures
import SwiftUI

// MARK: - GaugeListInspector

struct GaugeListInspector: View {

    // MARK: Internal

    @Bindable var gaugeSearchStore: StoreOf<GaugeSearchFeature>
    var favoritesStore: StoreOf<FavoriteGaugesFeature>?

    @Binding var mode: InspectorMode

    var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .nearby:
                nearbyContent
            case .favorites:
                favoritesContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Private

    @State private var searchText = ""

    @ViewBuilder
    private var nearbyContent: some View {
        switch gaugeSearchStore.results {
        case .initial, .loading:
            ContentUnavailableView {
                ProgressView()
            } description: {
                Text("Loading gauges...")
            }
        case .loaded(let gauges), .reloading(let gauges):
            if gauges.isEmpty {
                ContentUnavailableView(
                    "No Gauges",
                    systemImage: "drop.triangle",
                    description: Text("Pan the map to find gauges"))
            } else {
                gaugeList(gauges: filteredGauges(gauges))
            }
        case .error(let error):
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription))
        }
    }

    @ViewBuilder
    private var favoritesContent: some View {
        if let store = favoritesStore {
            FavoritesInspectorContent(store: store)
        } else {
            ContentUnavailableView(
                "Favorites Unavailable",
                systemImage: "star.slash",
                description: Text("Could not load favorites"))
        }
    }

    private func filteredGauges(_ gauges: [GaugeRef]) -> [GaugeRef] {
        guard !searchText.isEmpty else { return gauges }
        return gauges.filter { gauge in
            gauge.name.localizedStandardContains(searchText)
                || gauge.state.localizedStandardContains(searchText)
                || gauge.zone.localizedStandardContains(searchText)
        }
    }

    @ViewBuilder
    private func gaugeList(gauges: [GaugeRef]) -> some View {
        List(gauges) { gauge in
            GaugeListRow(gauge: gauge) {
                gaugeSearchStore.send(.goToGaugeDetail(gauge.id))
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Filter gauges")
    }
}

// MARK: - GaugeListRow

struct GaugeListRow: View {

    let gauge: GaugeRef
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(gauge.name)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(gauge.source.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary)
                        .clipShape(.capsule)
                    Text(gauge.state)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !gauge.zone.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(gauge.zone)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FavoritesInspectorContent

struct FavoritesInspectorContent: View {

    @Bindable var store: StoreOf<FavoriteGaugesFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            content
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

    @ViewBuilder
    private var content: some View {
        switch store.gauges {
        case .initial, .loading:
            ContentUnavailableView {
                ProgressView()
            } description: {
                Text("Loading favorites...")
            }
        case .loaded(let gauges), .reloading(let gauges):
            if gauges.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Star gauges from the detail view to add them here"))
            } else {
                List {
                    ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
                        FavoriteRowView(store: rowStore)
                    }
                }
                .listStyle(.sidebar)
            }
        case .error(let error):
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription))
        }
    }
}

// MARK: - FavoriteRowView

struct FavoriteRowView: View {

    @Bindable var store: StoreOf<FavoriteGaugeTileFeature>

    var body: some View {
        Button {
            store.send(.goToGaugeDetail(store.gauge.id))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.gauge.name)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(store.gauge.source.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary)
                        .clipShape(.capsule)
                    Text(store.gauge.state)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    GaugeListInspector(
        gaugeSearchStore: Store(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        },
        favoritesStore: Store(initialState: FavoriteGaugesFeature.State()) {
            FavoriteGaugesFeature()
        },
        mode: .constant(.nearby))
}

