//
//  GaugeDetailInfoSheet.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 10/18/24.
//

import GaugeSources
import SharedFeatures
import SwiftUI
import UIComponents

struct GaugeDetailInfoSheet: View {

    // MARK: Lifecycle

    init(gauge: GaugeRef? = nil, onClose: @escaping () -> Void) {
        self.gauge = gauge
        self.onClose = onClose
    }

    // MARK: Internal

    var body: some View {
        InfoSheetView(title: "Understanding This Gauge", onClose: onClose) {
            if let gauge {
                gaugeOverviewSection(gauge)
            }

            readingUnitsSection

            dataSourcesSection

            dataFreshnessSection

            if let gauge, gauge.source == .dwr || gauge.source == .lawa {
                limitedHistorySection
            }

            troubleshootingSection
        }
    }

    // MARK: Private

    private let gauge: GaugeRef?
    private let onClose: () -> Void

    private var readingUnitsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                unitRow(
                    label: "CFS",
                    description: "Cubic Feet per Second",
                    detail: "Volume of water flow. Higher values mean more water.")

                unitRow(
                    label: "FT",
                    description: "Feet (Gauge Height)",
                    detail: "Water level above a reference point at the station.")

                Divider()

                unitRow(
                    label: "CMS",
                    description: "Cubic Meters per Second",
                    detail: "Metric equivalent of CFS. Used in Canada and New Zealand.")

                unitRow(
                    label: "M",
                    description: "Meters (Gauge Height)",
                    detail: "Metric equivalent of FT.")
            }
        } header: {
            Label("Reading Units", systemImage: "ruler")
        }
    }

    private var dataSourcesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                sourceRow(source: .usgs, name: "US Geological Survey", region: "United States")
                sourceRow(source: .dwr, name: "CO Division of Water Resources", region: "Colorado")
                sourceRow(source: .environmentCanada, name: "Environment Canada", region: "Canada")
                sourceRow(source: .lawa, name: "Land Air Water Aotearoa", region: "New Zealand")
            }
        } header: {
            Label("Data Sources", systemImage: "building.columns")
        }
    }

    private var dataFreshnessSection: some View {
        Section {
            Text(
                """
        Readings refresh automatically when data is more than 30 minutes old. \
        The "Stale" badge appears when a gauge hasn't reported new data recently—this \
        usually means the station is offline or experiencing issues.
        """)
                .font(.callout)
        } header: {
            Label("Data Freshness", systemImage: "clock.arrow.circlepath")
        }
    }

    private var limitedHistorySection: some View {
        Section {
            Text(
                """
        This station only provides the most recent reading rather than historical data. \
        The chart will build up over time as new readings are collected.
        """)
                .font(.callout)
        } header: {
            Label("Limited History", systemImage: "chart.line.downtrend.xyaxis")
        }
    }

    private var troubleshootingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                troubleshootingRow(
                    icon: "exclamationmark.triangle",
                    problem: "No data showing",
                    solution: "The gauge station may be offline. Check back later.")

                troubleshootingRow(
                    icon: "arrow.clockwise",
                    problem: "Stale readings",
                    solution: "Data hasn't updated in over 30 minutes. This is normal for some stations.")

                troubleshootingRow(
                    icon: "chart.line.flattrend.xyaxis",
                    problem: "Flat or missing chart",
                    solution: "Some stations report infrequently. Allow time for data to accumulate.")
            }
        } header: {
            Label("Troubleshooting", systemImage: "wrench.and.screwdriver")
        }
    }

    @ViewBuilder
    private func gaugeOverviewSection(_ gauge: GaugeRef) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(gauge.name)
                    .font(.headline)

                Label(sourceDescription(for: gauge.source), systemImage: sourceIcon(for: gauge.source))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func unitRow(label: String, description: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(.body, design: .monospaced))
                .bold()
                .frame(width: 40, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(description)
                    .font(.callout)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sourceRow(source: GaugeSource, name: String, region: String) -> some View {
        HStack {
            Image(systemName: sourceIcon(for: source))
                .frame(width: 20)
                .foregroundStyle(sourceColor(for: source))

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.callout)
                Text(region)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func troubleshootingRow(icon: String, problem: String, solution: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(problem)
                    .font(.callout)
                    .bold()
                Text(solution)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Source Helpers

    private func sourceDescription(for source: GaugeSource) -> String {
        switch source {
        case .usgs:
            "US Geological Survey gauge station"
        case .dwr:
            "Colorado Division of Water Resources station"
        case .environmentCanada:
            "Environment Canada hydrometric station"
        case .lawa:
            "Land Air Water Aotearoa monitoring site"
        }
    }

    private func sourceIcon(for source: GaugeSource) -> String {
        switch source {
        case .usgs:
            "building.columns.fill"
        case .dwr:
            "mountain.2.fill"
        case .environmentCanada:
            "leaf.fill"
        case .lawa:
            "water.waves"
        }
    }

    private func sourceColor(for source: GaugeSource) -> Color {
        switch source {
        case .usgs:
            .blue
        case .dwr:
            .orange
        case .environmentCanada:
            .red
        case .lawa:
            .teal
        }
    }
}

#Preview("With Gauge") {
    GaugeDetailInfoSheet(
        gauge: GaugeRef(
            id: 1,
            name: "COLORADO RIVER AT GLENWOOD SPRINGS",
            siteID: "09085000",
            metric: .cfs,
            country: "US",
            state: "Colorado",
            zone: "",
            source: .usgs,
            favorite: true,
            primary: true,
            latitude: 39.5505,
            longitude: -107.3248,
            updatedAt: Date(),
            createdAt: Date()),
        onClose: { })
}

#Preview("Without Gauge") {
    GaugeDetailInfoSheet(onClose: { })
}
