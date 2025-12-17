//
//  GaugeReading.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import Foundation
import SQLiteData

// MARK: - GaugeReadingProtocol

public protocol GaugeReadingProtocol: Sendable {
  var id: Int { get }
  var siteID: String { get }
  var value: Double { get }
  var metric: String { get }
  var gaugeID: Gauge.ID { get }
  var createdAt: Date { get }
}

// MARK: - GaugeReading

@Table
public struct GaugeReading: Identifiable, Hashable, GaugeReadingProtocol, Sendable {
  public static let databaseTableName = "gauge_readings"
  public let id: Int
  public var siteID: String
  public var value: Double
  public var metric: String
  public var gaugeID: Gauge.ID
  public var createdAt: Date
}
