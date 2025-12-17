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
    public let id: Int
    public let siteID: String
    public let value: Double
    public let metric: String
    public let gaugeID: Gauge.ID
    public let createdAt: Date

    public init(
        id: Int,
        siteID: String,
        value: Double,
        metric: String,
        gaugeID: Gauge.ID,
        createdAt: Date
    ) {
        self.id = id
        self.siteID = siteID
        self.value = value
        self.metric = metric
        self.gaugeID = gaugeID
        self.createdAt = createdAt
    }
}

// MARK: - GaugeReading + ref

public extension GaugeReading {
    nonisolated var ref: GaugeReadingRef {
        GaugeReadingRef(
            id: id,
            siteID: siteID,
            value: value,
            metric: metric,
            gaugeID: gaugeID,
            createdAt: createdAt)
    }
}

// MARK: CustomStringConvertible

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

