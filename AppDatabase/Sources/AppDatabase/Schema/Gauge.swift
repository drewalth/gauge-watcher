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
}

// MARK: - Gauge
// TODO: Check out https://www.gaia-gis.it/fossil/libspatialite/index. Maybe we can improve searching on the map by nearest current location rather than state boundaries.
@Table
public struct Gauge: Identifiable, Hashable, GaugeProtocol, Sendable {
  public static let databaseTableName = "gauges"
  public let id: Int
  public var name: String
  public var siteID: String
  public var metric: GaugeSourceMetric
  public var country: String
  public var state: String
  public var zone: String
  public var source: GaugeSource
  public var favorite = false
  public var primary = false
  public var latitude: Double
  public var longitude: Double
  public var updatedAt: Date
  public var createdAt: Date
}
