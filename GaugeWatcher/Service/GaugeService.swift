//
//  GaugeService.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import Foundation
import GaugeDrivers
import GaugeSources
import SQLiteData

// MARK: - GaugeService

struct GaugeService {
    var loadGauge: (Gauge.ID) async throws -> Gauge
    var loadGauges: (GaugeQueryOptions) async throws -> [Gauge]
    var loadGaugeReadings: (GaugeReadingQuery) async throws -> [GaugeReading]
    var sync: (Gauge.ID) async throws -> Void
}

// MARK: DependencyKey

extension GaugeService: DependencyKey {
    static let liveValue: GaugeService = Self(loadGauge: { id in
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            guard let gauge = try Gauge.where { $0.id == id }.fetchOne(db) else {
                throw DatabaseServiceError.gaugeNotFound
            }
            return gauge
        }
    }, loadGauges: { options in
        @Dependency(\.defaultDatabase)
        var database
        return try await database.read { db in
            // implement the query options
            var query = Gauge.all
            if let name = options.name {
                // where name contains the query string
                query = query.where { $0.name.lower().contains(name.lowercased()) }
            }
            if let country = options.country {
                query = query.where { $0.country == country }
            }
            if let state = options.state {
                query = query.where { $0.state == state }
            }
            if let zone = options.zone {
                query = query.where { $0.zone == zone }
            }
            if let source = options.source {
                query = query.where { $0.source == source }
            }
            if let favorite = options.favorite {
                query = query.where { $0.favorite == favorite }
            }
            if let primary = options.primary {
                query = query.where { $0.primary == primary }
            }

            return try query.fetchAll(db)
        }

    }, loadGaugeReadings: { query in
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            var dbQuery = GaugeReading
                .where { $0.gaugeID == query.gaugeID }
                .order { $0.createdAt.desc() } // Most recent first
            
            // Apply date range filter if provided
            if let dateRange = query.dateRange {
                dbQuery = dbQuery
                    .where { $0.createdAt >= dateRange.start }
                    .where { $0.createdAt <= dateRange.end }
            }
            
            // Apply metric filter if provided
            if let metric = query.metric {
                dbQuery = dbQuery.where { $0.metric == metric }
            }
            
            // Apply limit if provided, otherwise default to 1000
            let limit = query.limit ?? 1000
            dbQuery = dbQuery.limit(limit)
            
            return try dbQuery.fetchAll(db)
        }
    }, sync: { gaugeID in
        @Dependency(\.defaultDatabase) var database
        
        // 1. Load gauge from database
        let gauge = try await database.read { db in
            guard let gauge = try Gauge.where { $0.id == gaugeID }.fetchOne(db) else {
                throw DatabaseServiceError.gaugeNotFound
            }
            return gauge
        }
        
        // 2. Convert GaugeSource to GaugeDriverSource
        let driverSource = gauge.source.toDriverSource
        
        // 3. Create metadata for sources that need it (e.g., Environment Canada needs province)
        let metadata: SourceMetadata? = {
            switch gauge.source {
            case .environmentCanada:
                let provinceCode = gauge.state.lowercased()
                guard let province = EnvironmentCanada.Province(rawValue: provinceCode) else {
                    return nil
                }
                return .environmentCanada(province: province)
            case .usgs, .dwr, .lawa:
                return nil
            }
        }()
        
        // 4. Create driver options
        let options = GaugeDriverOptions(
            siteID: gauge.siteID,
            source: driverSource,
            timePeriod: .predefined(.last24Hours), // Fetch last 24 hours for sync
            parameters: [.discharge, .height], // Fetch both discharge and height
            metadata: metadata
        )
        
        // 5. Fetch readings using unified API
        let factory = GaugeDriverFactory()
        let driverReadings = try await factory.fetchReadings(options: options)
        
        // 6. Save readings to database
        try await database.write { db in
            for driverReading in driverReadings {
                // Check if reading already exists (by siteID, timestamp, and metric)
                let existingCount = try GaugeReading
                    .where { $0.gaugeID == gaugeID }
                    .where { $0.siteID == driverReading.siteID }
                    .where { $0.createdAt == driverReading.timestamp }
                    .where { $0.metric == driverReading.unit.rawValue }
                    .fetchCount(db)
                
                // Only insert if it doesn't already exist
                if existingCount == 0 {
                    try #sql("""
                        INSERT INTO gaugeReadings (siteID, value, metric, gaugeID, createdAt)
                        VALUES (\(driverReading.siteID), \(driverReading.value), \(driverReading.unit.rawValue), \(gaugeID), \(driverReading.timestamp))
                    """).execute(db)
                }
            }
            
            // Update the gauge's updatedAt timestamp
            let now = Date()
            try #sql("""
                UPDATE gauges SET updatedAt = \(now) WHERE id = \(gaugeID)
            """).execute(db)
        }
    })
}

extension DependencyValues {
    var gaugeService: GaugeService {
        get { self[GaugeService.self] }
        set { self[GaugeService.self] = newValue }
    }
}

// MARK: - GaugeQueryOptions

struct GaugeQueryOptions {

    // MARK: Lifecycle

    init(
        name: String? = nil,
        country: String? = "US",
        state: String? = "AK",
        zone: String? = nil,
        source: GaugeSource? = .usgs,
        favorite: Bool? = nil,
        primary: Bool? = nil) {
        self.name = name
        self.country = country
        self.state = state
        self.zone = zone
        self.source = source
        self.favorite = favorite
        self.primary = primary
    }

    // MARK: Internal

    var name: String?
    var country: String?
    var state: String?
    var zone: String?
    var source: GaugeSource?
    var favorite: Bool?
    var primary: Bool?

}

// MARK: - GaugeReadingQuery

struct GaugeReadingQuery {

    // MARK: Lifecycle

    init(
        gaugeID: Gauge.ID,
        dateRange: DateInterval? = nil,
        metric: String? = nil,
        limit: Int? = nil) {
        self.gaugeID = gaugeID
        self.dateRange = dateRange
        self.metric = metric
        self.limit = limit
    }

    // MARK: Internal

    let gaugeID: Gauge.ID
    let dateRange: DateInterval?
    let metric: String?
    let limit: Int?
}

// MARK: - GaugeReadingQuery Convenience

extension GaugeReadingQuery {
    /// Returns all readings for a gauge (up to default limit)
    static func all(gaugeID: Gauge.ID, limit: Int? = 1000) -> GaugeReadingQuery {
        GaugeReadingQuery(gaugeID: gaugeID, limit: limit)
    }
    
    /// Returns readings for a specific metric
    static func forMetric(_ metric: String, gaugeID: Gauge.ID, limit: Int? = 1000) -> GaugeReadingQuery {
        GaugeReadingQuery(gaugeID: gaugeID, metric: metric, limit: limit)
    }
    
    /// Returns readings in the last N hours
    static func lastHours(_ hours: Int, gaugeID: Gauge.ID, metric: String? = nil) -> GaugeReadingQuery {
        let end = Date()
        let start = end.addingTimeInterval(-Double(hours) * 3600)
        return GaugeReadingQuery(
            gaugeID: gaugeID,
            dateRange: DateInterval(start: start, end: end),
            metric: metric
        )
    }
    
    /// Returns readings in the last N days
    static func lastDays(_ days: Int, gaugeID: Gauge.ID, metric: String? = nil) -> GaugeReadingQuery {
        let end = Date()
        let start = end.addingTimeInterval(-Double(days) * 86400)
        return GaugeReadingQuery(
            gaugeID: gaugeID,
            dateRange: DateInterval(start: start, end: end),
            metric: metric
        )
    }
}

// MARK: - DatabaseServiceError

enum DatabaseServiceError: Error {
    case gaugeNotFound
}
