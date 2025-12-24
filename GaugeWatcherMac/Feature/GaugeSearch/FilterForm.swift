//
//  FilterForm.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import AccessibleUI
import GaugeSources
import SharedFeatures
import SwiftUI

// MARK: - FilterForm

struct FilterForm: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                searchField
                countryPicker
                statePicker
                sourcePicker
                actionButtons
            }
            .padding()
        }
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
            get: { store.filterOptions.searchText },
            set: { newValue in
                updateFilter { $0.searchText = newValue }
            })
    }

    private var countryBinding: Binding<String?> {
        Binding(
            get: { store.filterOptions.country },
            set: { newValue in
                updateFilter {
                    $0.country = newValue
                    // Clear state when country changes
                    $0.state = nil
                    // Clear source if it's not valid for the new country
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

    @ViewBuilder
    private var header: some View {
        HStack {
            Label("Search Filters", systemImage: "line.3.horizontal.decrease.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if store.filterOptions.hasActiveFilters {
                Button("Clear", action: clearFilters)
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibleButton(label: "Clear Filters")
            }
        }
        .padding()
    }

    @ViewBuilder
    private var searchField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Search by name", text: searchTextBinding)
                    .accessibleTextField(label: "Search by name")
                    .textFieldStyle(.plain)
                    .onSubmit(applyFilters)
                if !store.filterOptions.searchText.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        updateFilter { $0.searchText = "" }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .labelStyle(.iconOnly)
                    .accessibleButton(label: "Clear Search")
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.5))
            .clipShape(.rect(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private var countryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Country")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Country", selection: countryBinding) {
                Text("Any Country").tag(String?.none)
                ForEach(StatesProvinces.Country.allCases, id: \.rawValue) { country in
                    Text(country.name).tag(Optional(country.rawValue))
                }
            }
            .labelsHidden()
            .accessiblePicker(
                label: "Country",
                selectedOption: countryBinding,
                options: StatesProvinces.Country.allCases.map { $0.name },
                hint: "Select a country")
        }
    }

    @ViewBuilder
    private var statePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(statePickerLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(statePickerLabel, selection: stateBinding) {
                Text("Any \(statePickerLabel)").tag(String?.none)
                ForEach(availableStates, id: \.abbreviation) { state in
                    Text(state.name).tag(Optional(state.abbreviation))
                }
            }
            .labelsHidden()
            .disabled(store.filterOptions.country == nil)
            .accessiblePicker(
                label: "\(statePickerLabel)",
                selectedOption: stateBinding,
                options: availableStates.map { $0.name },
                hint: "Select a \(statePickerLabel)")
        }
    }

    @ViewBuilder
    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Data Source")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Source", selection: sourceBinding) {
                Text("Any Source").tag(GaugeSource?.none)
                ForEach(availableSources, id: \.self) { source in
                    Text(sourceDisplayName(source)).tag(Optional(source))
                }
            }
            .labelsHidden()
            .accessiblePicker(label: "Source", selectedOption: sourceBinding, options: availableSources, hint: "Select a data source")
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: applyFilters) {
                HStack {
                    Spacer()
                    Label("Search", systemImage: "magnifyingglass")
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.filterOptions.hasActiveFilters)
            .accessibleButton(label: "Apply Search Filters")

            if store.results.isLoading() || store.results.isReloading() {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
    }

    private func updateFilter(_ transform: (inout FilterOptions) -> Void) {
        var options = store.filterOptions
        transform(&options)
        store.send(.updateFilterOptions(options))
    }

    private func applyFilters() {
        store.send(.applyFilters)
    }

    private func clearFilters() {
        store.send(.clearFilters)
    }

    // MARK: - Helpers

    private func sourceDisplayName(_ source: GaugeSource) -> String {
        switch source {
        case .usgs:
            "USGS (US Geological Survey)"
        case .dwr:
            "DWR (CA Dept. of Water Resources)"
        case .environmentCanada:
            "Environment Canada"
        case .lawa:
            "LAWA (NZ Land, Air, Water)"
        }
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

// MARK: - CollapsibleFilterForm

/// A compact version of FilterForm designed for use inside a DisclosureGroup.
/// Omits the header since the disclosure label provides context.
struct CollapsibleFilterForm: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField
            countryPicker
            statePicker
            sourcePicker
            actionButtons
        }
        .padding(.top, 8)
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
            get: { store.filterOptions.searchText },
            set: { newValue in
                updateFilter { $0.searchText = newValue }
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

    @ViewBuilder
    private var searchField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Name")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Search by name", text: searchTextBinding)
                    .accessibleTextField(label: "Search by name")
                    .textFieldStyle(.plain)
                    .onSubmit(applyFilters)
                if !store.filterOptions.searchText.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        updateFilter { $0.searchText = "" }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .labelStyle(.iconOnly)
                    .accessibleButton(label: "Clear Search")
                }
            }
            .padding(6)
            .background(.quaternary.opacity(0.5))
            .clipShape(.rect(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private var countryPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Country")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Country", selection: countryBinding) {
                Text("Any Country").tag(String?.none)
                ForEach(StatesProvinces.Country.allCases, id: \.rawValue) { country in
                    Text(country.name).tag(Optional(country.rawValue))
                }
            }
            .labelsHidden()
            .accessiblePicker(
                label: "Country",
                selectedOption: countryBinding,
                options: StatesProvinces.Country.allCases.map { $0.name },
                hint: "Select a country")
        }
    }

    @ViewBuilder
    private var statePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(statePickerLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(statePickerLabel, selection: stateBinding) {
                Text("Any \(statePickerLabel)").tag(String?.none)
                ForEach(availableStates, id: \.abbreviation) { state in
                    Text(state.name).tag(Optional(state.abbreviation))
                }
            }
            .labelsHidden()
            .disabled(store.filterOptions.country == nil)
            .accessiblePicker(
                label: "\(statePickerLabel)",
                selectedOption: stateBinding,
                options: availableStates.map { $0.name },
                hint: "Select a \(statePickerLabel)")
        }
    }

    @ViewBuilder
    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Data Source")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Source", selection: sourceBinding) {
                Text("Any Source").tag(GaugeSource?.none)
                ForEach(availableSources, id: \.self) { source in
                    Text(sourceDisplayName(source)).tag(Optional(source))
                }
            }
            .labelsHidden()
            .accessiblePicker(
                label: "Source",
                selectedOption: sourceBinding,
                options: availableSources,
                hint: "Select a data source")
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: applyFilters) {
                HStack {
                    Spacer()
                    Label("Search", systemImage: "magnifyingglass")
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.filterOptions.hasActiveFilters)
            .accessibleButton(label: "Apply Search Filters")

            Button("Clear", action: clearFilters)
                .buttonStyle(.bordered)
                .disabled(!store.filterOptions.hasActiveFilters)
                .accessibleButton(label: "Clear Filters")

            if store.results.isLoading() || store.results.isReloading() {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
    }

    private func updateFilter(_ transform: (inout FilterOptions) -> Void) {
        var options = store.filterOptions
        transform(&options)
        store.send(.updateFilterOptions(options))
    }

    private func applyFilters() {
        store.send(.applyFilters)
    }

    private func clearFilters() {
        store.send(.clearFilters)
    }

    private func sourceDisplayName(_ source: GaugeSource) -> String {
        switch source {
        case .usgs:
            "USGS"
        case .dwr:
            "DWR"
        case .environmentCanada:
            "Env. Canada"
        case .lawa:
            "LAWA"
        }
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

// MARK: - StateValue

private struct StateValue: Identifiable {
    let name: String
    let abbreviation: String

    var id: String { abbreviation }
}

extension StatesProvinces.USState {
    fileprivate var value: StateValue {
        StateValue(name: name, abbreviation: rawValue)
    }
}

extension StatesProvinces.CanadianProvince {
    fileprivate var value: StateValue {
        StateValue(name: name, abbreviation: rawValue)
    }
}

extension StatesProvinces.NewZealandRegion {
    fileprivate var value: StateValue {
        StateValue(name: name, abbreviation: rawValue)
    }
}

// MARK: - Preview

#Preview("FilterForm") {
    FilterForm(store: Store(initialState: GaugeSearchFeature.State()) {
        GaugeSearchFeature()
    })
    .frame(width: 320, height: 500)
}

#Preview("CollapsibleFilterForm") {
    CollapsibleFilterForm(store: Store(initialState: GaugeSearchFeature.State()) {
        GaugeSearchFeature()
    })
    .frame(width: 320, height: 400)
    .padding()
}
