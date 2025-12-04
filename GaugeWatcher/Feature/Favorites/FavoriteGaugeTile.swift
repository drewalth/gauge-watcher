//
//  FavoriteGaugeTile.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/3/25.
//

import ComposableArchitecture
import GaugeSources
import Loadable
import SwiftUI
import UIComponents

// MARK: - FavoriteGaugeTile

struct FavoriteGaugeTile: View {

    // MARK: Internal

    var store: StoreOf<FavoriteGaugeTileFeature>

    var body: some View {
        Button {
            store.send(.goToGaugeDetail(store.gauge.id))
        } label: {
            content
        }
        .buttonStyle(.plain)
        .task {
            store.send(.loadReadings)
        }
    }

    // MARK: Private

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            readingsContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top) {
            Text(store.gauge.name)
                .font(.headline)
                .lineLimit(2)

            Spacer(minLength: 8)

            if store.readings.isLoading() {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }

    @ViewBuilder
    private var readingsContent: some View {
        switch store.readings {
        case .initial, .loading:
            readingsPlaceholder

        case .loaded(let readings), .reloading(let readings):
            readingsDisplay(readings)

        case .error:
            errorDisplay
        }
    }

    @ViewBuilder
    private var readingsPlaceholder: some View {
        HStack(spacing: 16) {
            ReadingPlaceholder()
            ReadingPlaceholder()
        }
    }

    @ViewBuilder
    private var errorDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.caption)
            Text("Unable to load readings")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                store.send(.loadReadings)
            } label: {
                Text("Retry")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder
    private func readingsDisplay(_ readings: [GaugeReadingRef]) -> some View {
        let discharge = latestReading(for: [.cfs, .cms], from: readings)
        let height = latestReading(for: [.feetHeight, .meterHeight], from: readings)

        if discharge == nil, height == nil {
            HStack(spacing: 6) {
                Image(systemName: "drop.slash")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("No readings available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 20) {
                if let discharge {
                    ReadingCell(
                        label: "Discharge",
                        value: discharge.value,
                        unit: discharge.metric,
                        timestamp: discharge.createdAt)
                }

                if let height {
                    ReadingCell(
                        label: "Stage",
                        value: height.value,
                        unit: height.metric,
                        timestamp: height.createdAt)
                }
            }
        }
    }

    private func latestReading(
        for metrics: [GaugeSourceMetric],
        from readings: [GaugeReadingRef])
    -> GaugeReadingRef? {
        let metricStrings = Set(metrics.map { $0.rawValue.uppercased() })
        return readings.first { metricStrings.contains($0.metric.uppercased()) }
    }
}

// MARK: - ReadingCell

private struct ReadingCell: View {

    // MARK: Internal

    let label: String
    let value: Double
    let unit: String
    let timestamp: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(formattedValue)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()

                Text(unit.lowercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Private

    private var formattedValue: String {
        if value >= 1000 {
            return value.formatted(.number.precision(.fractionLength(0)))
        } else if value >= 100 {
            return value.formatted(.number.precision(.fractionLength(1)))
        } else {
            return value.formatted(.number.precision(.fractionLength(2)))
        }
    }
}

// MARK: - ReadingPlaceholder

private struct ReadingPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 50, height: 10)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 60, height: 20)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 40, height: 8)
        }
    }
}
