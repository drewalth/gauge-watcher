//
//  GaugeReadingChartControls.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import GaugeDrivers
import GaugeSources
import Loadable
import SharedFeatures
import SwiftUI

// MARK: - GaugeReadingChartControls

struct GaugeReadingChartControls: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        HStack(spacing: 12) {
            // Time period segmented picker
            timePeriodPicker

            // Metric picker (if multiple metrics available)
            if let metrics = store.availableMetrics, metrics.count > 1 {
                metricPicker(metrics: metrics)
            }

            // Refresh button
            refreshButton
        }
    }

    // MARK: Private

    @ViewBuilder
    private var timePeriodPicker: some View {
        Menu {
            ForEach(TimePeriod.PredefinedPeriod.allCases, id: \.self) { period in
                Button {
                    store.send(.setSelectedTimePeriod(period))
                } label: {
                    HStack {
                        Text(period.description)
                        if period == store.selectedTimePeriod {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(store.selectedTimePeriod.description)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var refreshButton: some View {
        Button {
            store.send(.sync)
        } label: {
            Group {
                if store.readings.isReloading() || store.gauge.isReloading() {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .padding(8)
        .background {
            Circle()
                .fill(.ultraThinMaterial)
        }
        .overlay {
            Circle()
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
        .disabled(store.readings.isLoading() || store.gauge.isLoading())
        .help("Refresh data")
    }

    @ViewBuilder
    private func metricPicker(metrics: [GaugeSourceMetric]) -> some View {
        Menu {
            ForEach(metrics, id: \.self) { metric in
                Button {
                    store.send(.setSelectedMetric(metric))
                } label: {
                    HStack {
                        Text(metric.rawValue)
                        if metric == store.selectedMetric {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "ruler")
                Text(store.selectedMetric?.rawValue ?? "Metric")
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

}
