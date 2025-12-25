//
//  FilterForm.swift
//  GaugeWatcher
//
//  Rich filter form for searching gauges by country, state, and source.
//

import ComposableArchitecture
import GaugeSources
import SharedFeatures
import SwiftUI

// MARK: - FilterForm

/// A form for filtering gauges by country, state/province, and data source.
struct FilterForm: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Name search
            searchField

            // Filter options in a card
            VStack(spacing: 0) {
                filterRow(label: "Country", content: countryPicker)
                Divider().padding(.leading, 16)
                filterRow(label: statePickerLabel, content: statePicker)
                Divider().padding(.leading, 16)
                filterRow(label: "Data Source", content: sourcePicker)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 12))

            // Search button
            searchButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Private

    private var statePickerLabel: String {
        switch store.filterOptions.country {
        case "CA":
            "Province"
        case "NZ":
            "Region"
        default:
            "State"
        }
    }

    private var availableStates: [StateValue] {
        switch store.filterOptions.country {
        case "US":
            StatesProvinces.USState.allCases.map(\.value)
        case "CA":
            StatesProvinces.CanadianProvince.allCases.map(\.value)
        case "NZ":
            StatesProvinces.NewZealandRegion.allCases.map(\.value)
        default:
            []
        }
    }

    private var availableSources: [GaugeSource] {
        switch store.filterOptions.country {
        case "US":
            [.usgs, .dwr]
        case "CA":
            [.environmentCanada]
        case "NZ":
            [.lawa]
        default:
            GaugeSource.allCases
        }
    }

    // MARK: - Bindings

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { store.localSearchText },
            set: { newValue in
                store.send(.setLocalSearchText(newValue))
            })
    }

    private var countryBinding: Binding<String?> {
        Binding(
            get: { store.filterOptions.country },
            set: { newValue in
                updateFilter {
                    $0.country = newValue
                    $0.state = nil
                    if let source = $0.source, !sourceValidForCountry(source, newValue) {
                        $0.source = nil
                    }
                }
            })
    }

    private var stateBinding: Binding<String?> {
        Binding(
            get: { store.filterOptions.state },
            set: { newValue in
                updateFilter { $0.state = newValue }
            })
    }

    private var sourceBinding: Binding<GaugeSource?> {
        Binding(
            get: { store.filterOptions.source },
            set: { newValue in
                updateFilter { $0.source = newValue }
            })
    }

    private var countryDisplayText: String {
        if
            let code = store.filterOptions.country,
            let country = StatesProvinces.Country(rawValue: code) {
            return country.name
        }
        return "Any"
    }

    private var stateDisplayText: String {
        if
            let abbr = store.filterOptions.state,
            let state = availableStates.first(where: { $0.abbreviation == abbr }) {
            return state.name
        }
        return "Any"
    }

    private var sourceDisplayText: String {
        store.filterOptions.source?.displayName ?? "Any"
    }

    // MARK: - Views

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            TextField("Search by name", text: searchTextBinding)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit(applyFilters)

            if !store.localSearchText.isEmpty {
                Button {
                    store.send(.setLocalSearchText(""))
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

    @ViewBuilder
    private var countryPicker: some View {
        Menu {
            Button("Any Country") {
                updateFilter {
                    $0.country = nil
                    $0.state = nil
                }
            }
            ForEach(StatesProvinces.Country.allCases, id: \.rawValue) { country in
                Button(country.name) {
                    updateFilter {
                        $0.country = country.rawValue
                        $0.state = nil
                        if let source = $0.source, !sourceValidForCountry(source, country.rawValue) {
                            $0.source = nil
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(countryDisplayText)
                    .foregroundStyle(store.filterOptions.country == nil ? .secondary : .primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statePicker: some View {
        Menu {
            Button("Any \(statePickerLabel)") {
                updateFilter { $0.state = nil }
            }
            ForEach(availableStates, id: \.abbreviation) { state in
                Button(state.name) {
                    updateFilter { $0.state = state.abbreviation }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(stateDisplayText)
                    .foregroundStyle(store.filterOptions.state == nil ? .secondary : .primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(store.filterOptions.country == nil)
        .opacity(store.filterOptions.country == nil ? 0.5 : 1)
    }

    @ViewBuilder
    private var sourcePicker: some View {
        Menu {
            Button("Any Source") {
                updateFilter { $0.source = nil }
            }
            ForEach(availableSources, id: \.self) { source in
                Button(source.displayName) {
                    updateFilter { $0.source = source }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(sourceDisplayText)
                    .foregroundStyle(store.filterOptions.source == nil ? .secondary : .primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var searchButton: some View {
        Button {
            applyFilters()
        } label: {
            HStack {
                if store.results.isLoading() || store.results.isReloading() {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!store.filterOptions.hasActiveFilters)
    }

    @ViewBuilder
    private func filterRow(label: String, content: some View) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func updateFilter(_ transform: (inout FilterOptions) -> Void) {
        var options = store.filterOptions
        transform(&options)
        store.send(.updateFilterOptions(options))
    }

    private func applyFilters() {
        store.send(.applyFilters)
    }

    private func sourceValidForCountry(_ source: GaugeSource, _ country: String?) -> Bool {
        switch country {
        case "US":
            source == .usgs || source == .dwr
        case "CA":
            source == .environmentCanada
        case "NZ":
            source == .lawa
        default:
            true
        }
    }
}

// MARK: - Preview

#Preview {
    FilterForm(store: Store(initialState: GaugeSearchFeature.State()) {
        GaugeSearchFeature()
    })
}
