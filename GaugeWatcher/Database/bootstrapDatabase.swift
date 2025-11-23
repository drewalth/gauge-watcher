//
//  bootstrapDatabase.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import SQLiteData
import ComposableArchitecture
import os

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
        CREATE TABLE "gauge_readings"(
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
        try migrator.migrate(database)
        defaultDatabase = database
    }
}

private let logger = Logger(category: "bootstrapDatabase")
