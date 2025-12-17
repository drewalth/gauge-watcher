//
//  GaugeDetail.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import SharedFeatures
import SwiftUI

// MARK: - GaugeDetail

struct GaugeDetail: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        content
            .navigationTitle(store.gauge.unwrap()?.name ?? "Gauge Detail")
            .task {
                store.send(.load)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.toggleFavorite)
                    } label: {
                        Label(
                            store.gauge.unwrap()?.favorite == true ? "Remove Favorite" : "Add Favorite",
                            systemImage: store.gauge.unwrap()?.favorite == true ? "star.fill" : "star"
                        )
                        .labelStyle(.iconOnly)
                    }
                }

                if store.gauge.unwrap()?.sourceURL != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            store.send(.openSource)
                        } label: {
                            Label("Open Source", systemImage: "safari")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
            }
    }

    // MARK: Private

    @ViewBuilder
    private var content: some View {
        switch store.gauge {
        case .initial, .loading:
            ProgressView("Loading gauge...")
        case .loaded(let gauge), .reloading(let gauge):
            gaugeContent(gauge)
        case .error(let error):
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
        }
    }

    @ViewBuilder
    private func gaugeContent(_ gauge: GaugeRef) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(gauge.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    HStack(spacing: 16) {
                        Label(gauge.source.rawValue, systemImage: "building.2")
                        Label(gauge.state, systemImage: "mappin")
                        Label(gauge.siteID, systemImage: "number")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                Divider()

                // Readings section
                readingsSection

                Divider()

                // Location info
                locationSection(gauge)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var readingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Readings")
                .font(.headline)

            switch store.readings {
            case .initial, .loading:
                ProgressView()
            case .loaded(let readings), .reloading(let readings):
                if readings.isEmpty {
                    Text("No readings available")
                        .foregroundStyle(.secondary)
                } else if let latest = readings.first {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Latest Reading")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(latest.value, specifier: "%.2f") \(latest.metric)")
                                .font(.title)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Updated")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(latest.createdAt, style: .relative)
                                .font(.callout)
                        }
                    }
                    .padding()
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            case .error(let error):
                Text("Failed to load readings: \(error.localizedDescription)")
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func locationSection(_ gauge: GaugeRef) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)

            HStack(spacing: 24) {
                LabeledContent("Latitude") {
                    Text(String(format: "%.4f", gauge.latitude))
                }
                LabeledContent("Longitude") {
                    Text(String(format: "%.4f", gauge.longitude))
                }
                LabeledContent("Country") {
                    Text(gauge.country)
                }
            }
            .font(.callout)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GaugeDetail(store: Store(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        })
    }
}
