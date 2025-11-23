//
//  DatabaseService.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import GaugeSources
import SQLiteData

// MARK: - DatabaseService

struct DatabaseService {
    var loadGauge: (Gauge.ID) async throws -> Gauge
    var loadGauges: (GaugeQueryOptions) async throws -> [Gauge]
    var loadGaugeReadings: (Gauge.ID) async throws -> [GaugeReading]
}

// MARK: DependencyKey

extension DatabaseService: DependencyKey {
    static let liveValue: DatabaseService = Self(loadGauge: { id in
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
                query = query.where { $0.name == name }
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
    })
}

extension DependencyValues {
    var databaseService: DatabaseService {
        get { self[DatabaseService.self] }
        set { self[DatabaseService.self] = newValue }
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
