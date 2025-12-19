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
        HStack(spacing: 8) {
            // Time period picker
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
                        Spacer()
                        if period == store.selectedTimePeriod {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label(store.selectedTimePeriod.shortDescription, systemImage: "calendar")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(store.selectedTimePeriod.description)
    }

    @ViewBuilder
    private var refreshButton: some View {
        Button {
            store.send(.sync)
        } label: {
            Group {
                if store.readings.isReloading() || store.gauge.isReloading() {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .font(.caption)
            .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
        .padding(6)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
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
                        Text(metric.displayName)
                        Spacer()
                        if metric == store.selectedMetric {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label(store.selectedMetric?.rawValue ?? "Metric", systemImage: "ruler")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(store.selectedMetric?.displayName ?? "Select metric")
    }
}

// MARK: - TimePeriod.PredefinedPeriod + ShortDescription

extension TimePeriod.PredefinedPeriod {
    /// Abbreviated description for compact UI
    var shortDescription: String {
        switch self {
        case .last24Hours:
            "24h"
        case .last7Days:
            "7d"
        case .last30Days:
            "30d"
        case .last90Days:
            "90d"
        }
    }
}

// MARK: - GaugeSourceMetric + DisplayName

extension GaugeSourceMetric {
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .cfs:
            "Discharge (CFS)"
        case .cms:
            "Discharge (CMS)"
        case .feetHeight:
            "Stage Height (FT)"
        case .meterHeight:
            "Stage Height (M)"
        }
    }
}
