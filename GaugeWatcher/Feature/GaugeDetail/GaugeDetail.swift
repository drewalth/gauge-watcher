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
        List {
            content()
        }.gaugeWatcherList()
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
        }.toolbar {
            ToolbarItem(placement: .primaryAction) {
                GaugeFavoriteToggle(onPress: {
                    store.send(.toggleFavorite)
                }, isFavorite: store.gauge.unwrap()?.favorite ?? false)
            }
        }
    }

    // MARK: Private

    @ViewBuilder
    private func content() -> some View {
        switch store.gauge {
        case .initial, .loading:
            ContinuousSpinner()
        case .loaded(let gauge), .reloading(let gauge):
            gaugeContent(gauge)
        case .error(let error):
            UtilityBlockView(kind: .error(error.localizedDescription))
        }
    }

    @ViewBuilder
    private func gaugeContent(_ gauge: GaugeRef) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(gauge.name)
                .font(.headline)
            statusBadge(gauge)
        }
        GaugeReadingChart(store: store)
        LatestGaugeReading(store: store)
        GaugeFlowForecast(store: store)
        if gauge.sourceURL != nil {
            Button("Source") {
                store.send(.openSource)
            }.buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func statusBadge(_ gauge: GaugeRef) -> some View {
        let statusInfo = gaugeStatusInfo(gauge)

        Label(statusInfo.label, systemImage: statusInfo.icon)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(statusInfo.color.opacity(0.15))
            }
            .foregroundStyle(statusInfo.color)
    }

    private func gaugeStatusInfo(_ gauge: GaugeRef) -> (label: String, icon: String, color: Color) {
        switch gauge.status {
        case .inactive:
            return ("Inactive", "exclamationmark.triangle.fill", .red)
        case .unknown:
            let isStale = gauge.isStale()
            return isStale
                ? ("Stale", "clock.badge.exclamationmark", .orange)
                : ("Current", "checkmark.circle", .green)
        case .active:
            let isStale = gauge.isStale()
            return isStale
                ? ("Stale", "clock.badge.exclamationmark", .orange)
                : ("Current", "checkmark.circle", .green)
        }
    }
}
