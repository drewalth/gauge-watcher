//
//  GaugeReading.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import Foundation
import SQLiteData

// MARK: - GaugeReadingProtocol

/// Common interface for gauge reading types.
public protocol GaugeReadingProtocol: Sendable {
  var id: Int { get }
  var siteID: String { get }
  var value: Double { get }
  var metric: String { get }
  var gaugeID: Gauge.ID { get }
  var createdAt: Date { get }
}

// MARK: - GaugeReading

/// A single observation from a gauge at a point in time.
///
/// Readings are deduplicated by the combination of `gaugeID`, `siteID`, `createdAt`, and `metric`
/// via a unique index. Use INSERT OR IGNORE when bulk-inserting to skip duplicates.
@Table
public struct GaugeReading: Identifiable, Hashable, GaugeReadingProtocol, Sendable {
  public static let databaseTableName = "gauge_readings"
  public let id: Int
  public var siteID: String
  /// The observed measurement (flow in cfs, height in ft, etc.).
  public var value: Double
  /// Unit of measurement (e.g., "cfs", "ft").
  public var metric: String
  /// Foreign key to the parent ``Gauge``.
  public var gaugeID: Gauge.ID
  /// Timestamp of the observation from the data provider.
  public var createdAt: Date
}
