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
        HStack(spacing: 20) {
            readingCard(
                title: "Current Reading",
                isLoading: true,
                icon: "waveform.path.ecg",
                gradient: [.blue, .cyan])

            readingCard(
                title: "Last Updated",
                isLoading: true,
                icon: "clock.fill",
                gradient: [.purple, .pink])
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
        HStack(spacing: 16) {
            // Primary reading card
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
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(reading.metric)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                trendIndicator(for: reading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: .accentColor.opacity(0.3), radius: 20, x: 0, y: 10)

            // Secondary info cards
            VStack(spacing: 16) {
                // Time card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.secondary)
                        Text("Last Updated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(reading.createdAt, style: .relative)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(reading.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }

                // Metric card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "ruler")
                            .foregroundStyle(.secondary)
                        Text("Metric")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(metricDisplayName(reading.metric))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(metricDescription(reading.metric))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
            }
            .frame(width: 200)
        }
        .frame(height: 180)
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

    @ViewBuilder
    private func readingCard(
        title: String,
        isLoading: Bool,
        icon: String,
        gradient: [Color])
    -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
            }
            .foregroundStyle(.white.opacity(0.8))

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
        .frame(height: 180)
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
