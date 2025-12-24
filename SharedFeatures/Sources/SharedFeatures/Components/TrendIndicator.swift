//
//  TrendIndicator.swift
//  SharedFeatures
//
//  Displays a trend indicator showing whether values are rising, falling, or stable.
//

import SwiftUI

// MARK: - Trend

/// Represents the trend of gauge readings over time.
public enum Trend: Equatable, Sendable {
    case rising(Double)
    case falling(Double)
    case stable

    // MARK: Public

    public var icon: String {
        switch self {
        case .rising:
            "arrow.up.right"
        case .falling:
            "arrow.down.right"
        case .stable:
            "arrow.right"
        }
    }

    public var description: String {
        switch self {
        case .rising(let percent):
            "Rising \(percent.formatted(.number.precision(.fractionLength(1))))%"
        case .falling(let percent):
            "Falling \(percent.formatted(.number.precision(.fractionLength(1))))%"
        case .stable:
            "Stable"
        }
    }
}

// MARK: - TrendIndicator

/// Displays a trend indicator with icon and description.
public struct TrendIndicator: View {

    // MARK: Lifecycle

    public init(trend: Trend) {
        self.trend = trend
    }

    // MARK: Public

    public var body: some View {
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

    // MARK: Private

    private let trend: Trend

}

// MARK: - Trend Calculation Helper

extension Trend {
    /// Calculates the trend from a list of readings.
    /// - Parameters:
    ///   - readings: Array of readings with `value`, `metric`, and `createdAt` properties.
    ///   - currentMetric: The metric to filter readings by.
    /// - Returns: The calculated trend.
    public static func calculate(
        from readings: [GaugeReadingRef],
        forMetric currentMetric: String)
    -> Trend {
        let now = Date()
        let oneDayAgo = now.addingTimeInterval(-86400)

        let recentReadings = readings
            .filter { $0.metric == currentMetric && $0.createdAt >= oneDayAgo }
            .sorted { $0.createdAt < $1.createdAt }

        guard recentReadings.count >= 2,
              let oldest = recentReadings.first,
              let newest = recentReadings.last
        else {
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
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        TrendIndicator(trend: .rising(15.5))
        TrendIndicator(trend: .falling(8.2))
        TrendIndicator(trend: .stable)
    }
    .padding()
    .background(Color.accentColor)
}

