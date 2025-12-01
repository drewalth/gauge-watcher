//
//  GaugeReadingRef.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/1/25.
//

import Foundation

// MARK: - GaugeReadingRef

/// Lightweight reference to a gauge reading
/// - Note: I added this because of threading issues related to SwiftData. Now that we're using SQLiteData, this may not be necessary.
nonisolated struct GaugeReadingRef: Identifiable, Hashable, GaugeReadingProtocol {
    let id: Int
    let siteID: String
    let value: Double
    let metric: String
    let gaugeID: Gauge.ID
    let createdAt: Date
}

// MARK: CustomStringConvertible

extension GaugeReadingRef: CustomStringConvertible {
    var description: String {
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
