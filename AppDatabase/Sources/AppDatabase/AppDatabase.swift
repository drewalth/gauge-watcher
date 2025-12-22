//
//  AppDatabase.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/17/25.
//

import Foundation
import GaugeSources
import os
import SQLiteData

// MARK: - AppDatabase

/// Entry point for database initialization. Call `initialize()` at app launch.
public enum AppDatabase {

  // MARK: Public

  /// Bootstraps the SQLite database, runs migrations, and prepares dependencies.
  ///
  /// Terminates the app if database initialization fails.
  public static func initialize() {
    do {
      try prepareDependencies {
        try $0.bootstrapDatabase()
      }
    } catch {
      fatalError("Failed to prepare database")
    }
  }

}

// MARK: Private

private let logger = Logger(subsystem: "com.drewalth.GaugeWatcher", category: "AppDatabase")

extension Database {
  /// Seeds the database with gauge data from bundled JSON sources.
  ///
  /// Filters out items without a valid `source` before inserting.
  /// Uses sequential IDs starting at 1.
  public func seedGaugeData(_ gaugeData: [GaugeSourceItem]) throws {
    let validGauges = gaugeData.filter { $0.source != nil }

    try seed {
      for (index, gauge) in validGauges.enumerated() {
        Gauge.Draft(
          id: index + 1,
          name: gauge.name,
          siteID: gauge.siteID,
          metric: gauge.metric,
          country: gauge.country,
          state: gauge.state,
          zone: gauge.zone ?? "",
          source: gauge.source!, // Safe because we filtered
          latitude: Double(gauge.latitude),
          longitude: Double(gauge.longitude),
          updatedAt: .distantPast,
          createdAt: .now)
      }
    }
  }
}

extension DependencyValues {
  /// Configures the SQLite database, enables query tracing in DEBUG, and runs migrations.
  ///
  /// In DEBUG builds, `eraseDatabaseOnSchemaChange` is enabled for faster iteration.
  /// Query profiling is logged to console (previews) or OSLog (device).
  public mutating func bootstrapDatabase() throws {
    @Dependency(\.context) var context
    let database = try SQLiteData.defaultDatabase()
    logger.debug(
      """
      App database:
      open "\(database.path)"
      """)
    var configuration = Configuration()
    #if DEBUG
    configuration.prepareDatabase { db in
      db.trace(options: .profile) {
        if context == .preview {
          print("\($0.expandedDescription)")
        } else {
          logger.debug("\($0.expandedDescription)")
        }
      }
    }
    #endif
    var migrator = DatabaseMigrator()
    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif

    // MARK: - Migrations

    // v0.1.0: Initial schema with gauges and readings tables
    migrator.registerMigration("create-tables-0.1.0") { db in
      try #sql("""
        CREATE TABLE "gauges"(
          "id" INTEGER PRIMARY KEY AUTOINCREMENT,
          "name" TEXT NOT NULL,
          "siteID" TEXT NOT NULL,
          "metric" TEXT NOT NULL,
          "country" TEXT NOT NULL,
          "state" TEXT NOT NULL,
          "zone" TEXT,
          "source" TEXT NOT NULL,
          "favorite" INTEGER NOT NULL DEFAULT 0,
          "primary" INTEGER NOT NULL DEFAULT 0,
          "latitude" REAL NOT NULL,
          "longitude" REAL NOT NULL,
          "updatedAt" TEXT NOT NULL,
          "createdAt" TEXT NOT NULL
        ) STRICT
        """)
      .execute(db)

      // TODO: Uncomment this when we have a better way to seed the database
      // add unique constraint to the siteID column
      // try #sql("""
      // CREATE UNIQUE INDEX "idx_gauges_siteID" ON "gauges"("siteID")
      // """)
      // .execute(db)

      try #sql("""
        CREATE TABLE "gaugeReadings"(
          "id" INTEGER PRIMARY KEY AUTOINCREMENT,
          "siteID" TEXT NOT NULL,
          "value" REAL NOT NULL,
          "metric" TEXT NOT NULL,
          "createdAt" TEXT NOT NULL,
          "gaugeID" INTEGER NOT NULL REFERENCES "gauges"("id") ON DELETE CASCADE
        ) STRICT
        """)
      .execute(db)
    }

    // v0.2.0: Spatial indexes for map bounding box queries
    migrator.registerMigration("add-spatial-indexes-0.2.0") { db in
      try #sql("""
        CREATE INDEX IF NOT EXISTS "idx_gauges_latitude" ON "gauges"("latitude")
        """)
      .execute(db)

      try #sql("""
        CREATE INDEX IF NOT EXISTS "idx_gauges_longitude" ON "gauges"("longitude")
        """)
      .execute(db)

      // Composite index for optimal bounding box queries
      try #sql("""
        CREATE INDEX IF NOT EXISTS "idx_gauges_lat_lon" ON "gauges"("latitude", "longitude")
        """)
      .execute(db)
    }

    // v0.3.0: Indexes for readings queries and unique constraint for deduplication
    migrator.registerMigration("add-gauge-readings-indexes-0.3.0") { db in
      try #sql("""
        CREATE INDEX IF NOT EXISTS "idx_gaugeReadings_gaugeID" ON "gaugeReadings"("gaugeID")
        """)
      .execute(db)

      try #sql("""
        CREATE INDEX IF NOT EXISTS "idx_gaugeReadings_gaugeID_createdAt" ON "gaugeReadings"("gaugeID", "createdAt")
        """)
      .execute(db)

      // Enables INSERT OR IGNORE for duplicate prevention
      try #sql("""
        CREATE UNIQUE INDEX IF NOT EXISTS "idx_gaugeReadings_unique"
        ON "gaugeReadings"("gaugeID", "siteID", "createdAt", "metric")
        """)
      .execute(db)
    }

    // v0.4.0: Status column for gauge operational state
    migrator.registerMigration("add-status-column-0.4.0") { db in
      try #sql("""
        ALTER TABLE "gauges" ADD COLUMN "status" TEXT NOT NULL DEFAULT "unknown"
        """)
      .execute(db)
    }

    // v0.5.0: Status column for individual reading state
    migrator.registerMigration("add-status-column-0.5.0") { db in
      try #sql("""
        ALTER TABLE "gaugeReadings" ADD COLUMN "status" TEXT NOT NULL DEFAULT "unknown"
        """)
      .execute(db)
    }

    try migrator.migrate(database)
    defaultDatabase = database
  }
}
