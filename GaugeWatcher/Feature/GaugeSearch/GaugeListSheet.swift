//
//  GaugeListSheet.swift
//  GaugeWatcher
//
//  Apple Maps-style bottom sheet for browsing and filtering gauges.
//

import ComposableArchitecture
import GaugeSources
import SharedFeatures
import SwiftUI

// MARK: - GaugeListSheet

/// A resizable bottom sheet for browsing gauges with search and filter capabilities.
struct GaugeListSheet: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Compact header - always visible
            compactHeader

            Divider()
                .padding(.horizontal, 16)

            // Mode toggle
            searchModeToggle

            Divider()
                .padding(.horizontal, 16)

            // Content based on mode
            switch store.searchMode {
            case .viewport:
                viewportContent
            case .filtered:
                filteredContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Private

    @State private var searchText = ""

    private var allGauges: [GaugeRef] {
        store.results.unwrap() ?? []
    }

    private var displayedGauges: [GaugeRef] {
        guard !searchText.isEmpty else { return allGauges }
        return allGauges.filter { gauge in
            gauge.name.localizedStandardContains(searchText)
                || gauge.state.localizedStandardContains(searchText)
                || gauge.zone.localizedStandardContains(searchText)
        }
    }

    private var searchModeBinding: Binding<SearchMode> {
        Binding(
            get: { store.searchMode },
            set: { store.send(.setSearchMode($0)) })
    }

    // MARK: - Compact Header

    @ViewBuilder
    private var compactHeader: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: store.searchMode == .viewport ? "map" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            // Summary text
            Text(compactSummaryText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Spacer()

            // Loading indicator
            if store.results.isLoading() || store.results.isReloading() {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var compactSummaryText: String {
        if store.searchMode == .filtered {
            if store.filterOptions.hasActiveFilters {
                return "Filters active"
            } else {
                return "Search by filters"
            }
        } else {
            let count = allGauges.count
            if count == 0 {
                return "Pan map to find gauges"
            } else {
                return "\(count) gauge\(count == 1 ? "" : "s") in view"
            }
        }
    }

    @ViewBuilder
    private var searchModeToggle: some View {
        Picker("Search Mode", selection: searchModeBinding) {
            Text("Map View")
                .tag(SearchMode.viewport)
            Text("Filters")
                .tag(SearchMode.filtered)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Viewport Mode Content

    @ViewBuilder
    private var viewportContent: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Results count
            HStack {
                Text(headerTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 16)

            // Gauge list
            switch store.results {
            case .initial, .loading:
                loadingView
            case .loaded(let gauges), .reloading(let gauges):
                if gauges.isEmpty {
                    emptyNearbyView
                } else if displayedGauges.isEmpty {
                    noSearchResultsView
                } else {
                    gaugeList
                }
            case .error(let error):
                errorView(error.localizedDescription)
            }
        }
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            TextField("Search gauges", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }

    private var headerTitle: String {
        if searchText.isEmpty {
            "\(allGauges.count) gauge\(allGauges.count == 1 ? "" : "s")"
        } else {
            "\(displayedGauges.count) of \(allGauges.count)"
        }
    }

    @ViewBuilder
    private var gaugeList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayedGauges) { gauge in
                    GaugeListRow(gauge: gauge) {
                        store.send(.goToGaugeDetail(gauge.id))
                    }
                    if gauge.id != displayedGauges.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Filtered Mode Content

    @ViewBuilder
    private var filteredContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                FilterForm(store: store)

                if store.filterOptions.hasActiveFilters {
                    filteredResultsContent
                }
            }
        }
    }

    @ViewBuilder
    private var filteredResultsContent: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)

            switch store.results {
            case .initial:
                hintView("Configure filters and tap Search")
            case .loading:
                loadingView
            case .loaded(let gauges), .reloading(let gauges):
                if gauges.isEmpty {
                    hintView("No gauges match your filters")
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("\(gauges.count) result\(gauges.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)

                        Divider()
                            .padding(.horizontal, 16)

                        LazyVStack(spacing: 0) {
                            ForEach(gauges) { gauge in
                                GaugeListRow(gauge: gauge) {
                                    store.send(.goToGaugeDetail(gauge.id))
                                }
                                if gauge.id != gauges.last?.id {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            case .error(let error):
                errorView(error.localizedDescription)
            }
        }
    }

    // MARK: - Utility Views

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private var emptyNearbyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Pan the map to find gauges")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private var noSearchResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No gauges match \"\(searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private func hintView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    GaugeListSheet(
        store: Store(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        })
}

