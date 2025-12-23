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

/// Common interface for gauge types, enabling testing with mock implementations.
public protocol GaugeProtocol {
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
  /// Operational status of the gauge (active, inactive, unknown).
  var status: GaugeOperationalStatus { get }
}

// MARK: - GaugeOperationalStatus

/// Represents the operational status of a gauge station.
public enum GaugeOperationalStatus: String, CaseIterable, Sendable, Codable {
  /// Gauge is actively reporting data.
  case active
  /// Gauge is not currently reporting data (offline, decommissioned, seasonal).
  case inactive
  /// Status has not been determined yet.
  case unknown
}

// MARK: - GaugeOperationalStatus + QueryBindable

extension GaugeOperationalStatus: QueryBindable { }

// MARK: - Gauge

/// A water monitoring station with location, source provider, and user preferences.
///
/// The `siteID` uniquely identifies the gauge within its `source` provider (e.g., USGS site number).
/// Coordinates enable map display and spatial queries.
// TODO: Consider libspatialite for nearest-location queries instead of state boundaries.
@Table
public struct Gauge: Identifiable, Hashable, GaugeProtocol, Sendable {
  public static let databaseTableName = "gauges"
  public let id: Int
  public var name: String
  /// Provider-specific identifier (e.g., USGS site number).
  public var siteID: String
  public var metric: GaugeSourceMetric
  public var country: String
  public var state: String
  public var zone: String
  /// Data provider (USGS, Environment Canada, etc.).
  public var source: GaugeSource
  /// User has marked this gauge as a favorite.
  public var favorite = false
  /// User's primary gauge, shown prominently in the UI.
  public var primary = false
  public var latitude: Double
  public var longitude: Double
  public var updatedAt: Date
  public var createdAt: Date
  /// Operational status indicating if the gauge is actively reporting data.
  public var status: GaugeOperationalStatus = .unknown
}
