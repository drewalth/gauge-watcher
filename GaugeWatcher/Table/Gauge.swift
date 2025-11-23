//
//  Gauge.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import Foundation
import GaugeSources
import SQLiteData

// MARK: - GaugeProtocol

protocol GaugeProtocol {
    var id: Int { get }
    var name: String { get }
    var siteID: String { get }
    var metric: GaugeSourceMetric { get }
    var country: String { get }
    var state: String { get }
    var zone: String { get }
    var source: GaugeSource { get }
    var favorite: Bool { get }
    var primary: Bool { get }
    var latitude: Double { get }
    var longitude: Double { get }
    var updatedAt: Date { get }
    var createdAt: Date { get }
}

// MARK: - Gauge

@Table
struct Gauge: Identifiable, Hashable, GaugeProtocol {
    static let databaseTableName = "gauges"
    let id: Int
    var name: String
    var siteID: String
    var metric: GaugeSourceMetric
    var country: String
    var state: String
    var zone: String
    var source: GaugeSource
    var favorite = false
    var primary = false
    var latitude: Double
    var longitude: Double
    var updatedAt: Date
    var createdAt: Date
}

// MARK: - GaugeRef

nonisolated struct GaugeRef: Identifiable, Hashable, GaugeProtocol {
    let id: Int
    let name: String
    let siteID: String
    let metric: GaugeSourceMetric
    let country: String
    let state: String
    let zone: String
    let source: GaugeSource
    let favorite: Bool
    let primary: Bool
    let latitude: Double
    let longitude: Double
    let updatedAt: Date
    let createdAt: Date
}

extension Gauge {
    nonisolated var ref: GaugeRef {
        GaugeRef(
            id: id,
            name: name,
            siteID: siteID,
            metric: metric,
            country: country,
            state: state,
            zone: zone,
            source: source,
            favorite: favorite,
            primary: primary,
            latitude: latitude,
            longitude: longitude,
            updatedAt: updatedAt,
            createdAt: createdAt)
    }
}
