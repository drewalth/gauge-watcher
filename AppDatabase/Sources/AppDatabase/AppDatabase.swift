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

public enum AppDatabase {

  // MARK: Public

  public func initialize() {
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
  func seedGaugeData(_ gaugeData: [GaugeSourceItem]) throws {
    // Filter out any items without a source before seeding
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
  mutating func bootstrapDatabase() throws {
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

    // Add spatial indexes for efficient bounding box queries
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

    // Add indexes and constraints for gaugeReadings performance
    migrator.registerMigration("add-gauge-readings-indexes-0.3.0") { db in
      // Index for query performance (reading by gaugeID)
      try #sql("""
        CREATE INDEX IF NOT EXISTS "idx_gaugeReadings_gaugeID" ON "gaugeReadings"("gaugeID")
        """)
      .execute(db)

      // Composite index for duplicate detection and time-range queries
      try #sql("""
        CREATE INDEX IF NOT EXISTS "idx_gaugeReadings_gaugeID_createdAt" ON "gaugeReadings"("gaugeID", "createdAt")
        """)
      .execute(db)

      // Unique constraint to prevent duplicate readings
      // This allows INSERT OR IGNORE to work efficiently
      try #sql("""
        CREATE UNIQUE INDEX IF NOT EXISTS "idx_gaugeReadings_unique"
        ON "gaugeReadings"("gaugeID", "siteID", "createdAt", "metric")
        """)
      .execute(db)
    }

    // Add `status` column to `gauges` table
    migrator.registerMigration("add-status-column-0.4.0") { db in
      try #sql("""
        ALTER TABLE "gauges" ADD COLUMN "status" TEXT NOT NULL DEFAULT "unknown"
        """)
      .execute(db)
    }

    // Add `status` column to `gaugeReadings` table
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
