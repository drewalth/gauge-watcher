//
//  LatestGaugeReading.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import Loadable
import SharedFeatures
import SwiftUI

// MARK: - LatestGaugeReading

struct LatestGaugeReading: View {

    // MARK: Internal

    var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        switch store.readings {
        case .initial, .loading:
            loadingView
        case .loaded(let readings), .reloading(let readings):
            if let reading = readings.first {
                heroReadingView(reading)
            } else {
                emptyView
            }
        case .error(let error):
            errorView(error)
        }
    }

    // MARK: Private

    private var loadingView: some View {
        VStack(spacing: 32) {
            // Primary card loading
            VStack {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Current Reading")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 100)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
            }

            // Secondary cards loading
            HStack(spacing: 12) {
                loadingSecondaryCard(title: "Last Updated", icon: "clock.fill")
                loadingSecondaryCard(title: "Metric", icon: "ruler")
            }
        }
    }

    private func loadingSecondaryCard(title: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
    }

    private var emptyView: some View {
        HStack {
            ContentUnavailableView(
                "No Readings",
                systemImage: "drop.halffull",
                description: Text("No readings available for this gauge"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private func errorView(_ error: Error) -> some View {
        HStack {
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.red.opacity(0.1))
        }
    }

    @ViewBuilder
    private func heroReadingView(_ reading: GaugeReadingRef) -> some View {
        VStack(spacing: 12) {
            // Primary reading card - full width
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))

                    Text("Current Reading")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    if store.readings.isReloading() {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(reading.value, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(reading.metric)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    trendIndicator(for: reading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            .shadow(color: .accentColor.opacity(0.3), radius: 12, x: 0, y: 6)

            // Secondary info cards - side by side, 50% each
            HStack(spacing: 12) {
                // Time card
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.secondary)
                        Text("Last Updated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(reading.createdAt, style: .relative)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(reading.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }

                // Metric card
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "ruler")
                            .foregroundStyle(.secondary)
                        Text("Metric")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(reading.metric)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(metricDescription(reading.metric))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
            }
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
