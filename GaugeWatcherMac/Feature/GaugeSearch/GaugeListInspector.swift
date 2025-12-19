//
//  GaugeListInspector.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import SharedFeatures
import SwiftUI

// MARK: - GaugeListInspector
// TODO: split up var computed views into separate structs
struct GaugeListInspector: View {

    // MARK: Internal

    @Bindable var gaugeSearchStore: StoreOf<GaugeSearchFeature>
    var favoritesStore: StoreOf<FavoriteGaugesFeature>?

    @Binding var mode: InspectorMode

    var body: some View {
        switch mode {
        case .nearby:
            nearbyContent
        case .favorites:
            favoritesContent
        }
    }

    // MARK: Private

    @State private var searchText = ""

    private var allGauges: [GaugeRef] {
        gaugeSearchStore.results.unwrap() ?? []
    }

    private var displayedGauges: [GaugeRef] {
        filteredGauges(allGauges)
    }

    @ViewBuilder
    private var nearbyContent: some View {
        VStack(spacing: 0) {
            searchModeToggle
            Divider()
            searchModeContent
            Spacer()
        }
    }

    @ViewBuilder
    private var searchModeToggle: some View {
        Picker("Search Mode", selection: searchModeBinding) {
            Label("Map View", systemImage: "map")
                .tag(SearchMode.viewport)
            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                .tag(SearchMode.filtered)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding()
    }

    private var searchModeBinding: Binding<SearchMode> {
        Binding(
            get: { gaugeSearchStore.searchMode },
            set: { gaugeSearchStore.send(.setSearchMode($0)) })
    }

    @ViewBuilder
    private var searchModeContent: some View {
        switch gaugeSearchStore.searchMode {
        case .viewport:
            viewportContent
        case .filtered:
            filteredContent
        }
    }

    @ViewBuilder
    private var viewportContent: some View {
        switch gaugeSearchStore.results {
        case .initial, .loading:
            loadingView("Loading gauges...")
        case .loaded(let gauges), .reloading(let gauges):
            if gauges.isEmpty {
                emptyNearbyView
            } else {
                gaugeListContent
            }
        case .error(let error):
            errorView(error.localizedDescription)
        }
    }

    @ViewBuilder
    private var filteredContent: some View {
        VStack(spacing: 0) {
            FilterForm(store: gaugeSearchStore)

            // Show results below the form when filters are applied
            if gaugeSearchStore.filterOptions.hasActiveFilters {
                Divider()
                filteredResultsContent
            }
        }
    }

    @ViewBuilder
    private var filteredResultsContent: some View {
        switch gaugeSearchStore.results {
        case .initial:
            ContentUnavailableView(
                "Set Filters",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Configure filters above and tap Search"))
        case .loading:
            loadingView("Searching...")
        case .loaded(let gauges), .reloading(let gauges):
            if gauges.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No gauges match your filters"))
            } else {
                filteredResultsList(gauges)
            }
        case .error(let error):
            errorView(error.localizedDescription)
        }
    }

    @ViewBuilder
    private func filteredResultsList(_ gauges: [GaugeRef]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(gauges.count) result\(gauges.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if gaugeSearchStore.results.isReloading() {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                ForEach(gauges) { gauge in
                    GaugeListRow(gauge: gauge) {
                        gaugeSearchStore.send(.selectGaugeForInspector(gauge.id))
                    }
                }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var gaugeListContent: some View {
        VStack(spacing: 0) {
            inspectorHeader
            Divider()
            if displayedGauges.isEmpty {
                noSearchResultsView
            } else {
                gaugeList
            }
        }
    }

    @ViewBuilder
    private var inspectorHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search gauges", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill", action: clearSearch)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .labelStyle(.iconOnly)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.5))
            .clipShape(.rect(cornerRadius: 8))

            HStack(alignment: .center) {
                Text(headerTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if gaugeSearchStore.results.isLoading() || gaugeSearchStore.results.isReloading() {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }.frame(height: 30)
        }
        .padding()
    }

    private var headerTitle: String {
        if searchText.isEmpty {
            "\(allGauges.count) gauges in view"
        } else {
            "\(displayedGauges.count) of \(allGauges.count) gauges"
        }
    }

    @ViewBuilder
    private var gaugeList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(displayedGauges) { gauge in
                    GaugeListRow(gauge: gauge) {
                        gaugeSearchStore.send(.selectGaugeForInspector(gauge.id))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var favoritesContent: some View {
        if let store = favoritesStore {
            FavoritesInspectorContent(
                store: store,
                onGaugeTapped: { gaugeID in
                    gaugeSearchStore.send(.selectGaugeForInspector(gaugeID))
                })
        } else {
            errorView("Could not load favorites")
        }
    }

    @ViewBuilder
    private var emptyNearbyView: some View {
        ContentUnavailableView(
            "No Gauges",
            systemImage: "drop.triangle",
            description: Text("Pan the map to find gauges"))
    }

    @ViewBuilder
    private var noSearchResultsView: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "magnifyingglass",
            description: Text("No gauges match \"\(searchText)\""))
    }

    @ViewBuilder
    private func loadingView(_ message: String) -> some View {
        ContentUnavailableView {
            ProgressView()
                .scaleEffect(0.5)
        } description: {
            Text(message)
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView(
            "Error",
            systemImage: "exclamationmark.triangle",
            description: Text(message))
    }

    private func filteredGauges(_ gauges: [GaugeRef]) -> [GaugeRef] {
        guard !searchText.isEmpty else { return gauges }
        return gauges.filter { gauge in
            gauge.name.localizedStandardContains(searchText)
                || gauge.state.localizedStandardContains(searchText)
                || gauge.zone.localizedStandardContains(searchText)
        }
    }

    private func clearSearch() {
        searchText = ""
    }
}

// MARK: - GaugeListRow

struct GaugeListRow: View {

    // MARK: Internal

    let gauge: GaugeRef
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Source indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(sourceColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(gauge.name)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(gauge.source.rawValue.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(sourceColor)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(gauge.state)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !gauge.zone.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(gauge.zone)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isHovering ? Color.primary.opacity(0.06) : .clear)
            .clipShape(.rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    // MARK: Private

    @State private var isHovering = false

    private var sourceColor: Color {
        switch gauge.source.rawValue.lowercased() {
        case "usgs":
            .blue
        case "dwr":
            .green
        default:
            .orange
        }
    }
}

// MARK: - FavoritesInspectorContent

struct FavoritesInspectorContent: View {

    // MARK: Internal

    @Bindable var store: StoreOf<FavoriteGaugesFeature>

    var onGaugeTapped: (Int) -> Void

    var body: some View {
        content
            .task {
                store.send(.load)
            }
    }

    // MARK: Private

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
                VStack(spacing: 0) {
                    favoritesHeader(count: gauges.count)
                    Divider()
                    favoritesList
                }
            }
        case .error(let error):
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription))
        }
    }

    @ViewBuilder
    private var favoritesList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
                    FavoriteRowView(store: rowStore, onTap: onGaugeTapped)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func favoritesHeader(count: Int) -> some View {
        HStack {
            Label("\(count) favorite\(count == 1 ? "" : "s")", systemImage: "star.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

}

// MARK: - FavoriteRowView

struct FavoriteRowView: View {

    // MARK: Internal

    @Bindable var store: StoreOf<FavoriteGaugeTileFeature>

    var onTap: (Int) -> Void

    var body: some View {
        Button {
            onTap(store.gauge.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.gauge.name)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(store.gauge.source.rawValue.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(sourceColor)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(store.gauge.state)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isHovering ? Color.primary.opacity(0.06) : .clear)
            .clipShape(.rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    // MARK: Private

    @State private var isHovering = false

    private var sourceColor: Color {
        switch store.gauge.source.rawValue.lowercased() {
        case "usgs":
            .blue
        case "dwr":
            .green
        default:
            .orange
        }
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
        .frame(width: 320, height: 600)
}
