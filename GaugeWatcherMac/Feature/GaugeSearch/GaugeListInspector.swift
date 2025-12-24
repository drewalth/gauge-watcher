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
        switch mode {
        case .nearby:
            nearbyContent
        case .favorites:
            favoritesContent
        }
    }

    // MARK: Private

    @State private var isFiltersExpanded = false

    private var allGauges: [GaugeRef] {
        gaugeSearchStore.results.unwrap() ?? []
    }

    private var displayedGauges: [GaugeRef] {
        gaugeSearchStore.filteredResults
    }

    private var hasActiveFilters: Bool {
        gaugeSearchStore.filterOptions.hasActiveFilters
    }

    private var searchText: String {
        gaugeSearchStore.localSearchText
    }

    private var appliedSearchText: String {
        gaugeSearchStore.appliedSearchText
    }

    @ViewBuilder
    private var nearbyContent: some View {
        VStack(spacing: 0) {
            // Search field at top
            searchField
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Collapsible filters
            collapsibleFiltersSection

            Divider()
                .padding(.horizontal, 16)

            gaugeResultsContent
            Spacer()
        }
    }

    // MARK: - Search Field

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { gaugeSearchStore.localSearchText },
            set: { gaugeSearchStore.send(.setLocalSearchText($0)) })
    }

    @ViewBuilder
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search gauges", text: searchTextBinding)
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
    }

    // MARK: - Collapsible Filters Section

    @ViewBuilder
    private var collapsibleFiltersSection: some View {
        DisclosureGroup(isExpanded: $isFiltersExpanded) {
            CollapsibleFilterForm(store: gaugeSearchStore)
        } label: {
            filterDisclosureLabel
        }
        .disclosureGroupStyle(CustomDisclosureStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var filterDisclosureLabel: some View {
        HStack(spacing: 8) {
            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                .font(.subheadline)
                .foregroundStyle(hasActiveFilters ? .primary : .secondary)

            if hasActiveFilters {
                Text("Active")
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue, in: .capsule)
            }
        }
    }

    // MARK: - Results Content

    @ViewBuilder
    private var gaugeResultsContent: some View {
        if hasActiveFilters {
            filteredResultsContent
        } else {
            viewportContent
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
    private var filteredResultsContent: some View {
        switch gaugeSearchStore.results {
        case .initial:
            ContentUnavailableView(
                "Apply Filters",
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
                VStack(spacing: 0) {
                    filteredResultsHeader(totalCount: gauges.count, displayedCount: displayedGauges.count)
                    Divider()
                    if displayedGauges.isEmpty {
                        noSearchResultsView
                    } else {
                        gaugeResultsList(displayedGauges)
                    }
                }
            }
        case .error(let error):
            errorView(error.localizedDescription)
        }
    }

    @ViewBuilder
    private func filteredResultsHeader(totalCount: Int, displayedCount: Int) -> some View {
        HStack {
            if appliedSearchText.isEmpty {
                Text("\(totalCount) result\(totalCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(displayedCount) of \(totalCount) results")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if gaugeSearchStore.results.isLoading() || gaugeSearchStore.results.isReloading() {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func gaugeResultsList(_ gauges: [GaugeRef]) -> some View {
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

    @ViewBuilder
    private var gaugeListContent: some View {
        VStack(spacing: 0) {
            gaugeCountHeader
            Divider()
                .padding(.horizontal, 16)
            if displayedGauges.isEmpty {
                noSearchResultsView
            } else {
                gaugeList
            }
        }
    }

    @ViewBuilder
    private var gaugeCountHeader: some View {
        HStack(alignment: .center) {
            Text(headerTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if gaugeSearchStore.results.isLoading() || gaugeSearchStore.results.isReloading() {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var headerTitle: String {
        if appliedSearchText.isEmpty {
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

    private func clearSearch() {
        gaugeSearchStore.send(.setLocalSearchText(""))
    }
}

// MARK: - GaugeListRow

struct GaugeListRow: View, Equatable {

    // MARK: Internal

    let gauge: GaugeRef
    let onTap: () -> Void
    
    static func == (lhs: GaugeListRow, rhs: GaugeListRow) -> Bool {
        lhs.gauge.id == rhs.gauge.id
    }

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
        .if(gauge.favorite) {
//            $0.glassEffect(.regular.tint(Color.yellow.opacity(0.25)).interactive())
            $0.glassEffect(in: .rect(cornerRadius: 8.0))
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


// MARK: - CustomDisclosureStyle

/// A custom disclosure group style with improved hit testing and macOS-native feel.
///
/// Features:
/// - Full-width tappable header area
/// - Hover effect for visual feedback
/// - Smooth expand/collapse animation with proper clipping
/// - "show/hide" toggle text instead of chevron
struct CustomDisclosureStyle: DisclosureGroupStyle {

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureHeader(
                isExpanded: configuration.isExpanded,
                onToggle: { configuration.isExpanded.toggle() },
                label: { configuration.label })

            // Animated content with smooth height transition
            DisclosureContent(isExpanded: configuration.isExpanded) {
                configuration.content
            }
        }
    }
}

// MARK: - DisclosureContent

/// Wrapper that provides smooth height animation for disclosure content.
private struct DisclosureContent<Content: View>: View {

    let isExpanded: Bool
    @ViewBuilder let content: () -> Content

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        content()
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { contentHeight = geometry.size.height }
                        .onChange(of: geometry.size.height) { _, newHeight in
                            contentHeight = newHeight
                        }
                }
            }
            .frame(height: isExpanded ? nil : 0, alignment: .top)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
            .animation(.smooth(duration: 0.25), value: isExpanded)
    }
}

// MARK: - DisclosureHeader

/// The tappable header row for the disclosure group.
private struct DisclosureHeader<Label: View>: View {

    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovering = false

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                label()
                Spacer(minLength: 0)
                toggleIndicator
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(DisclosureHeaderButtonStyle(isHovering: isHovering))
        .onHover { hovering in
            isHovering = hovering
        }
    }

    @ViewBuilder
    private var toggleIndicator: some View {
        Text(isExpanded ? "hide" : "show")
            .font(.caption.lowercaseSmallCaps())
            .foregroundStyle(isHovering ? Color.primary : Color.accentColor)
            .contentTransition(.identity)
    }
}

// MARK: - DisclosureHeaderButtonStyle

/// Custom button style for the disclosure header with hover feedback.
private struct DisclosureHeaderButtonStyle: ButtonStyle {

    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
