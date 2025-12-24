//
//  GaugeDetail.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import AppDatabase
import AppTelemetry
import ComposableArchitecture
import GaugeSources
import Loadable
import SharedFeatures
import SwiftUI
import UIAppearance
import UIComponents

struct GaugeDetail: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        ScrollView {
            content()
                .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .trackView("GaugeDetail", {
            if let gauge = store.gauge.unwrap() {
                return [
                    "Name": gauge.name,
                    "Source": gauge.source.rawValue,
                    "SiteID": gauge.siteID,
                    "Country": gauge.country,
                    "State": gauge.state
                ]
            }
            return nil
        }())
        .task {
            store.send(.load)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                GaugeFavoriteToggle(onPress: {
                    store.send(.toggleFavorite)
                }, isFavorite: store.gauge.unwrap()?.favorite ?? false)
            }
        }
    }

    // MARK: Private

    @ViewBuilder
    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header skeleton
            GaugeDetailHeader(gauge: nil)

            // Latest reading card skeleton
            LatestGaugeReadingCard(
                reading: nil,
                readings: [],
                isLoading: true,
                gaugeStatus: .active)

            // Chart skeleton
            GaugeReadingChartView(
                readings: [],
                selectedTimePeriod: store.selectedTimePeriod,
                selectedMetric: store.selectedMetric,
                isLoading: true,
                isInactive: false,
                onTimePeriodChange: { store.send(.setSelectedTimePeriod($0)) },
                onMetricChange: { store.send(.setSelectedMetric($0)) },
                availableMetrics: store.availableMetrics ?? [])

            Spacer(minLength: 24)
        }
    }

    @ViewBuilder
    private func content() -> some View {
        switch store.gauge {
        case .initial, .loading:
            skeletonContent
        case .loaded(let gauge), .reloading(let gauge):
            gaugeContent(gauge)
        case .error(let error):
            UtilityBlockView(kind: .error(error.localizedDescription))
        }
    }

    @ViewBuilder
    private func gaugeContent(_ gauge: GaugeRef) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Hero header with badges
            GaugeDetailHeader(gauge: gauge)

            // Latest reading card
            LatestGaugeReadingCard(
                reading: store.readings.unwrap()?.first,
                readings: store.readings.unwrap() ?? [],
                isLoading: store.readings.isLoading(),
                gaugeStatus: gauge.status)

            // Flow chart
            GaugeReadingChartView(
                readings: store.readings.unwrap() ?? [],
                selectedTimePeriod: store.selectedTimePeriod,
                selectedMetric: store.selectedMetric,
                isLoading: store.readings.isLoading(),
                isInactive: gauge.status == .inactive,
                onTimePeriodChange: { store.send(.setSelectedTimePeriod($0)) },
                onMetricChange: { store.send(.setSelectedMetric($0)) },
                availableMetrics: store.availableMetrics ?? [])

            // Forecast
            GaugeFlowForecastView(
                forecast: store.forecast,
                forecastAvailable: store.forecastAvailable,
                onLoadForecast: { store.send(.getForecast) },
                onInfoTapped: { store.send(.setForecastInfoSheetPresented(true)) })

            // Info section
            infoSection(gauge)

            // Source button
            if gauge.sourceURL != nil {
                Button {
                    store.send(.openSource)
                } label: {
                    HStack {
                        Spacer()
                        Label("View Source", systemImage: "safari")
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer(minLength: 24)
        }
    }

    @ViewBuilder
    private func infoSection(_ gauge: GaugeRef) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Details", systemImage: "info.circle.fill")
                .font(.headline)

            VStack(spacing: 12) {
                infoRow(label: "Zone", value: gauge.zone.isEmpty ? "—" : gauge.zone)
                infoRow(label: "Primary Metric", value: gauge.metric.rawValue)
                infoRow(label: "Last Updated", value: gauge.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding(14)
        .outlinedTile()
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
    }
}
