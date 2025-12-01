//
//  GaugeReading.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import Foundation
import SQLiteData

// MARK: - GaugeReadingProtocol

protocol GaugeReadingProtocol: Sendable {
    var id: Int { get }
    var siteID: String { get }
    var value: Double { get }
    var metric: String { get }
    var gaugeID: Gauge.ID { get }
    var createdAt: Date { get }
}

// MARK: - GaugeReading

@Table
struct GaugeReading: Identifiable, Hashable, GaugeReadingProtocol {
    static let databaseTableName = "gauge_readings"
    let id: Int
    var siteID: String
    var value: Double
    var metric: String
    var gaugeID: Gauge.ID
    var createdAt: Date
}

extension GaugeReading {
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
