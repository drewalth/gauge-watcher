//
//  LatestGaugeReading.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import AppDatabase
import Loadable
import SharedFeatures
import SwiftUI

// MARK: - LatestGaugeReading

struct LatestGaugeReading: View {

    // MARK: Internal

    var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        if let gauge = store.gauge.unwrap(), gauge.status == .inactive {
            inactiveGaugeView
        } else {
            VStack(spacing: 12) {
                primaryCard
                secondaryCards
            }
        }
    }

    // MARK: Private

    // Fixed heights for consistent layout (includes padding)
    private let primaryCardContentHeight: CGFloat = 82 // Inner content height
    private let secondaryCardContentHeight: CGFloat = 52 // Inner content height

    private var isLoading: Bool {
        store.readings.isInitial() || store.readings.isLoading()
    }

    private var currentReading: GaugeReadingRef? {
        store.readings.unwrap()?.first
    }

    // Total height for empty/error states
    private var totalComponentHeight: CGFloat {
        (primaryCardContentHeight + 32) + 12 + (secondaryCardContentHeight + 24)
    }

    @ViewBuilder
    private var primaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row - always visible, fixed height
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                Text("Current Reading")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(height: 24)

            Spacer()
                .frame(height: 12)

            // Content row - fixed height container
            HStack(alignment: .center, spacing: 6) {
                if let reading = currentReading {
                    Text(reading.value, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(reading.metric)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    trendIndicator(for: reading)
                } else {
                    // Skeleton placeholders
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.3))
                        .frame(width: 100, height: 46)
                        .shimmering()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.2))
                        .frame(width: 36, height: 20)
                        .shimmering()

                    Spacer()

                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(width: 70, height: 28)
                        .shimmering()
                }
            }
            .frame(height: 46)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: primaryCardContentHeight + 32) // content + vertical padding
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: .accentColor.opacity(isLoading ? 0.1 : 0.3), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private var secondaryCards: some View {
        HStack(spacing: 12) {
            secondaryCard(
                title: "Last Updated",
                icon: "clock.fill",
                primaryText: currentReading.map { Text($0.createdAt, style: .relative) },
                secondaryText: currentReading.map { Text($0.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute()) })

            secondaryCard(
                title: "Metric",
                icon: "ruler",
                primaryText: currentReading.map { Text($0.metric) },
                secondaryText: currentReading.map { Text(metricDescription($0.metric)) })
        }
    }

    private var emptyView: some View {
        HStack {
            ContentUnavailableView(
                "No Readings",
                systemImage: "drop.halffull",
                description: Text("No readings available for this gauge"))
        }
        .frame(maxWidth: .infinity, minHeight: totalComponentHeight)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func secondaryCard(
        title: String,
        icon: String,
        primaryText: Text?,
        secondaryText: Text?)
    -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - fixed height
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 16)

            Spacer()
                .frame(height: 6)

            // Primary text - fixed height
            Group {
                if let primary = primaryText {
                    primary
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.primary.opacity(0.1))
                        .frame(width: 80, height: 17)
                        .shimmering()
                }
            }
            .frame(height: 17, alignment: .leading)

            Spacer()
                .frame(height: 4)

            // Secondary text - fixed height
            Group {
                if let secondary = secondaryText {
                    secondary
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.primary.opacity(0.06))
                        .frame(width: 90, height: 11)
                        .shimmering()
                }
            }
            .frame(height: 11, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(12)
        .frame(height: secondaryCardContentHeight + 24) // content + vertical padding
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
    }

    private func errorView(_ error: Error) -> some View {
        HStack {
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription))
        }
        .frame(maxWidth: .infinity, minHeight: totalComponentHeight)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.red.opacity(0.1))
        }
    }

    private var inactiveGaugeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gauge Inactive")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("This gauge is not currently reporting data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("The gauge may be offline, decommissioned, or experiencing seasonal shutdown. Check back later or view the source for more information.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.red.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.red.opacity(0.2), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func trendIndicator(for reading: GaugeReadingRef) -> some View {
        let readings = store.readings.unwrap() ?? []
        let trend = calculateTrend(current: reading, readings: readings)

        HStack(spacing: 6) {
            Image(systemName: trend.icon)
                .font(.caption)

            Text(trend.description)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.white.opacity(0.2))
        }
        .foregroundStyle(.white.opacity(0.9))
    }

    private func calculateTrend(current: GaugeReadingRef, readings: [GaugeReadingRef]) -> Trend {
        // Get readings from the same metric in the last 24 hours
        let now = Date()
        let oneDayAgo = now.addingTimeInterval(-86400)

        let recentReadings = readings
            .filter { $0.metric == current.metric && $0.createdAt >= oneDayAgo }
            .sorted { $0.createdAt < $1.createdAt }

        guard recentReadings.count >= 2 else {
            return .stable
        }

        // Compare first and last readings
        guard let oldest = recentReadings.first, let newest = recentReadings.last else {
            return .stable
        }

        let change = newest.value - oldest.value
        let percentChange = abs(change / oldest.value) * 100

        if percentChange < 5 {
            return .stable
        } else if change > 0 {
            return .rising(percentChange)
        } else {
            return .falling(percentChange)
        }
    }

    private func metricDisplayName(_ metric: String) -> String {
        switch metric.uppercased() {
        case "CFS":
            return "Cubic Ft/Sec"
        case "FT":
            return "Feet"
        case "M":
            return "Meters"
        case "M3/S":
            return "Cubic M/Sec"
        case "DEGC":
            return "Celsius"
        case "DEGF":
            return "Fahrenheit"
        default:
            return metric
        }
    }

    private func metricDescription(_ metric: String) -> String {
        switch metric.uppercased() {
        case "CFS":
            return "Flow rate measurement"
        case "FT":
            return "Water stage height"
        case "M":
            return "Water stage height"
        case "M3/S":
            return "Flow rate measurement"
        case "DEGC", "DEGF":
            return "Water temperature"
        default:
            return "Gauge measurement"
        }
    }
}

// MARK: - Trend

private enum Trend {
    case rising(Double)
    case falling(Double)
    case stable

    // MARK: Internal

    var icon: String {
        switch self {
        case .rising:
            return "arrow.up.right"
        case .falling:
            return "arrow.down.right"
        case .stable:
            return "arrow.right"
        }
    }

    var description: String {
        switch self {
        case .rising(let percent):
            return "Rising \(percent.formatted(.number.precision(.fractionLength(1))))%"
        case .falling(let percent):
            return "Falling \(percent.formatted(.number.precision(.fractionLength(1))))%"
        case .stable:
            return "Stable"
        }
    }
}
