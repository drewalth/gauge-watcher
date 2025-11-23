//
//  GaugeReading.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import Foundation
import SQLiteData

@Table
struct GaugeReading: Identifiable, Hashable {
    static let databaseTableName = "gauge_readings"
    let id: Int
    var siteID: String
    var value: Double
    var metric: String
    var gaugeID: Gauge.ID
    var createdAt: Date
}
