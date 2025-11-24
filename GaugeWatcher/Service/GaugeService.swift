//
//  GaugeService.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import GaugeSources
import SQLiteData
import GaugeDrivers

// MARK: - GaugeService

struct GaugeService {
    var loadGauge: (Gauge.ID) async throws -> Gauge
    var loadGauges: (GaugeQueryOptions) async throws -> [Gauge]
    var loadGaugeReadings: (Gauge.ID) async throws -> [GaugeReading]
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

    }, loadGaugeReadings: { id in
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try GaugeReading.where { $0.gaugeID == id }.fetchAll(db)
        }
    }, sync: { _ in
        let options = GaugeDriverOptions(
            siteID: "09380000",
            source: .usgs,
            timePeriod: .predefined(.last7Days),
            parameters: [.discharge, .height]
        )

        // Fetch readings
        let factory = GaugeDriverFactory()
        let readings = try await factory.fetchReadings(options: options)

        // Process results
        for reading in readings {
            print("\(reading.timestamp): \(reading.value) \(reading.unit.rawValue)")
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

// MARK: - DatabaseServiceError

enum DatabaseServiceError: Error {
    case gaugeNotFound
}
