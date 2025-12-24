//
//  LatestGaugeReadingCard.swift
//  SharedFeatures
//
//  A polished card displaying the latest gauge reading with trend indicator.
//

import AppDatabase
import Loadable
import SwiftUI

// MARK: - LatestGaugeReadingCard

/// Displays the latest gauge reading in a polished card format with trend indicator.
public struct LatestGaugeReadingCard: View {

    // MARK: Lifecycle

    public init(
        reading: GaugeReadingRef?,
        readings: [GaugeReadingRef],
        isLoading: Bool,
        gaugeStatus: GaugeOperationalStatus)
    {
        self.reading = reading
        self.readings = readings
        self.isLoading = isLoading
        self.gaugeStatus = gaugeStatus
    }

    // MARK: Public

    public var body: some View {
        if gaugeStatus == .inactive {
            inactiveGaugeView
        } else {
            VStack(spacing: 12) {
                primaryCard
                secondaryCards
            }
        }
    }

    // MARK: Private

    private let reading: GaugeReadingRef?
    private let readings: [GaugeReadingRef]
    private let isLoading: Bool
    private let gaugeStatus: GaugeOperationalStatus

    // Fixed heights for consistent layout
    private let primaryCardContentHeight: CGFloat = 82
    private let secondaryCardContentHeight: CGFloat = 52

    private var trend: Trend {
        guard let reading else { return .stable }
        return Trend.calculate(from: readings, forMetric: reading.metric)
    }

    @ViewBuilder
    private var primaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
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

            // Content row
            HStack(alignment: .center, spacing: 6) {
                if let reading {
                    Text(reading.value, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(reading.metric)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    TrendIndicator(trend: trend)
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
        .frame(height: primaryCardContentHeight + 32)
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
                primaryText: reading.map { Text($0.createdAt, style: .relative) },
                secondaryText: reading.map { Text($0.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute()) })

            secondaryCard(
                title: "Metric",
                icon: "ruler",
                primaryText: reading.map { Text($0.metric) },
                secondaryText: reading.map { Text(metricDescription($0.metric)) })
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
            // Header
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

            // Primary text
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

            // Secondary text
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
        .frame(height: secondaryCardContentHeight + 24)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
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

    private func metricDescription(_ metric: String) -> String {
        switch metric.uppercased() {
        case "CFS":
            "Flow rate measurement"
        case "FT":
            "Water stage height"
        case "M":
            "Water stage height"
        case "M3/S", "CMS":
            "Flow rate measurement"
        case "DEGC", "DEGF":
            "Water temperature"
        default:
            "Gauge measurement"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        LatestGaugeReadingCard(
            reading: GaugeReadingRef(
                id: 1,
                value: 1234.56,
                metric: "CFS",
                createdAt: Date(),
                gaugeID: 1),
            readings: [],
            isLoading: false,
            gaugeStatus: .active)

        LatestGaugeReadingCard(
            reading: nil,
            readings: [],
            isLoading: true,
            gaugeStatus: .active)

        LatestGaugeReadingCard(
            reading: nil,
            readings: [],
            isLoading: false,
            gaugeStatus: .inactive)
    }
    .padding()
}

