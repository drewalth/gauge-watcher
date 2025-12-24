//
//  GaugeReadingRef.swift
//  SharedFeatures
//

import AppDatabase
import Foundation

// MARK: - GaugeReadingRef

/// Lightweight reference to a gauge reading
/// - Note: I added this because of threading issues related to SwiftData. Now that we're using SQLiteData, this may not be necessary.
public nonisolated struct GaugeReadingRef: Identifiable, Hashable, GaugeReadingProtocol, Sendable {

    // MARK: Lifecycle

    public init(
        id: Int,
        siteID: String,
        value: Double,
        metric: String,
        gaugeID: Gauge.ID,
        createdAt: Date) {
        self.id = id
        self.siteID = siteID
        self.value = value
        self.metric = metric
        self.gaugeID = gaugeID
        self.createdAt = createdAt
    }

    /// Convenience initializer for previews and testing.
    public init(id: Int, value: Double, metric: String, createdAt: Date, gaugeID: Int) {
        self.id = id
        siteID = ""
        self.value = value
        self.metric = metric
        self.gaugeID = gaugeID
        self.createdAt = createdAt
    }

    // MARK: Public

    public let id: Int
    public let siteID: String
    public let value: Double
    public let metric: String
    public let gaugeID: Gauge.ID
    public let createdAt: Date

}

// MARK: - GaugeReading + ref

extension GaugeReading {
    public nonisolated var ref: GaugeReadingRef {
        GaugeReadingRef(
            id: id,
            siteID: siteID,
            value: value,
            metric: metric,
            gaugeID: gaugeID,
            createdAt: createdAt)
    }
}

// MARK: - GaugeReadingRef + CustomStringConvertible

extension GaugeReadingRef: CustomStringConvertible {
    public var description: String {
        """
    GaugeReadingRef(
        id: \(id),
        siteID: \(siteID),
        value: \(value),
        metric: \(metric),
        gaugeID: \(gaugeID),
        createdAt: \(createdAt)
    )
    """
    }
}
