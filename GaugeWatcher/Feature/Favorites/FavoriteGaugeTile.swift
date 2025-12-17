//
//  FavoriteGaugeTile.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/3/25.
//

import ComposableArchitecture
import GaugeSources
import Loadable
import SharedFeatures
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
        VStack(alignment: .leading, spacing: 16) {
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
        ReadingsPlaceholderGrid()
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
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 2) {
                GridRow {
                    if discharge != nil {
                        Text("DISCHARGE")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.tertiary)
                    }
                    if height != nil {
                        Text("STAGE")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.tertiary)
                    }
                }

                GridRow {
                    if let discharge {
                        ReadingValue(value: discharge.value, unit: discharge.metric)
                    }
                    if let height {
                        ReadingValue(value: height.value, unit: height.metric)
                    }
                }

                GridRow {
                    if let discharge {
                        Text(discharge.createdAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let height {
                        Text(height.createdAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
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

// MARK: - ReadingValue

private struct ReadingValue: View {

    // MARK: Internal

    let value: Double
    let unit: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(formattedValue)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()

            Text(unit.lowercased())
                .font(.caption)
                .foregroundStyle(.secondary)
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

// MARK: - ReadingsPlaceholderGrid

private struct ReadingsPlaceholderGrid: View {

    // MARK: Internal

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 2) {
            GridRow {
                placeholderRect(width: 60, height: 10, opacity: 0.15)
                placeholderRect(width: 36, height: 10, opacity: 0.15)
            }
            GridRow {
                placeholderRect(width: 70, height: 22, opacity: 0.12)
                placeholderRect(width: 50, height: 22, opacity: 0.12)
            }
            GridRow {
                placeholderRect(width: 55, height: 10, opacity: 0.1)
                placeholderRect(width: 55, height: 10, opacity: 0.1)
            }
        }
    }

    // MARK: Private

    private func placeholderRect(width: CGFloat, height: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.secondary.opacity(opacity))
            .frame(width: width, height: height)
    }
}
