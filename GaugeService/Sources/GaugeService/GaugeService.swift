//
//  GaugeService.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import FlowForecast
import Foundation
import GaugeDrivers
import GaugeSources
import os
import SQLiteData
import AppDatabase

// MARK: - GaugeService

public struct GaugeService: Sendable {
    public var seeded: @Sendable () async -> Result<Bool, Error>
    public var loadAllSources: @Sendable () async throws -> [GaugeSourceItem]
    public var loadGauge: @Sendable (Gauge.ID) async throws -> Gauge
    public var loadGauges: @Sendable (GaugeQueryOptions) async throws -> [Gauge]
    public var loadGaugeReadings: @Sendable (GaugeReadingQuery) async throws -> [GaugeReading]
    public var sync: @Sendable (Gauge.ID) async throws -> Void
    public var toggleFavorite: @Sendable (Gauge.ID) async throws -> Void
    public var loadFavoriteGauges: @Sendable () async throws -> [Gauge]
    public var forecast: @Sendable (String, USGS.USGSParameter) async throws -> [ForecastDataPoint]
}

// MARK: DependencyKey

extension GaugeService: DependencyKey {
    public static let liveValue: GaugeService = Self(
        seeded: {
            do {
                @Dependency(\.defaultDatabase) var database
                let gaugeSources = try await GaugeSources.loadAll()
                let numberOfSources = gaugeSources.count
                let numberOfGauges = try await database.read { db in
                    try Gauge.all.fetchCount(db)
                }

                return .success(numberOfGauges == numberOfSources)
            } catch {
                logger.error("Error checking if gauges have already been seeded: \(error.localizedDescription)")
                return .failure(error)
            }
        },
        loadAllSources: {
            try await GaugeSources.loadAll()
        },
        loadGauge: { id in
            @Dependency(\.defaultDatabase) var database
            return try await database.read { db in
                guard let gauge = try Gauge.where({ $0.id == id }).fetchOne(db) else {
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

                // Bounding box spatial query - replaces state-based filtering when provided
                if let bbox = options.boundingBox {
                    query = query.where {
                        $0.latitude >= bbox.minLatitude &&
                            $0.latitude <= bbox.maxLatitude &&
                            $0.longitude >= bbox.minLongitude &&
                            $0.longitude <= bbox.maxLongitude
                    }

                    // Safety limit: cap results for bounding box queries to prevent UI overload
                    // Even at reasonable zoom, dense areas could have hundreds of gauges
                    return try query.limit(500).fetchAll(db)
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
                timePeriod: .predefined(.last30Days),
                parameters: [.discharge, .height],
                metadata: metadata)

            // 5. Fetch readings using unified API
            let factory = GaugeDriverFactory()
            let result = await factory.fetchReadings(options: options)

            // 6. Handle the result
            guard case .success(let fetchResult) = result else {
                if case .failure(let error) = result {
                    throw error
                }
                throw DatabaseServiceError.unknownError
            }

            // 7. Save readings to database
            // Use INSERT OR IGNORE to skip duplicates efficiently (relies on unique index)
            try await database.write { db in
                for driverReading in fetchResult.readings {
                    try #sql("""
                INSERT OR IGNORE INTO gaugeReadings (siteID, value, metric, gaugeID, createdAt)
                VALUES (\(driverReading.siteID), \(driverReading.value), \(driverReading.unit
                                                                            .rawValue), \(gaugeID), \(driverReading
                                                                                                        .timestamp))
            """).execute(db)
                }

                // Update the gauge's updatedAt timestamp and status
                let now = Date()
                try #sql("""
              UPDATE gauges SET updatedAt = \(now), status = \(fetchResult.status.rawValue) WHERE id = \(gaugeID)
          """).execute(db)
            }
        }, toggleFavorite: { gaugeID in
            @Dependency(\.defaultDatabase) var database
            try await database.write { db in
                try #sql("""
              UPDATE gauges SET favorite = NOT favorite WHERE id = \(gaugeID)
          """).execute(db)
            }
        }, loadFavoriteGauges: {
            @Dependency(\.defaultDatabase) var database
            return try await database.read { db in
                try Gauge.where { $0.favorite == true }.fetchAll(db)
            }
        }, forecast: { siteID, readingParam in
            guard readingParam != .temperature else {
                throw GaugeServiceError.unsupportedForecastReadingParam
            }

            FlowForecast.CodableHelper.dateFormatter = forecastDateFormatter

            let now = Date()
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!

            // "00060"
            // or
            //
            let result = try await UsgsAPI.forecastUsgsForecastPost(uSGSFlowForecastRequest: .init(
                                                                        siteId: siteID,
                                                                        readingParameter: readingParam.rawValue,
                                                                        startDate: oneYearAgo,
                                                                        endDate: now))

            // Use compactMap to combine transformation and filtering
            // Reuse a single calendar for all date parsing
            let calendar = Calendar.current
            let year = calendar.component(.year, from: now)

            let cleanedForecast: [ForecastDataPoint] = result.compactMap { value in
                // Filter out invalid values early
                guard
                    let forecast = value.forecast,
                    let lower = value.lowerErrorBound,
                    let upper = value.upperErrorBound,
                    forecast != 0, lower != 0, upper != 0
                else {
                    return nil
                }

                // Parse date efficiently with shared calendar
                guard let index = parseForecastDate(value.index, year: year, calendar: calendar) else {
                    return nil
                }

                return ForecastDataPoint(
                    index: index,
                    value: forecast,
                    lowerErrorBound: lower,
                    upperErrorBound: upper)
            }
            return cleanedForecast
        })
}

public extension DependencyValues {
    var gaugeService: GaugeService {
        get { self[GaugeService.self] }
        set { self[GaugeService.self] = newValue }
    }
}

// MARK: - GaugeQueryOptions

public struct GaugeQueryOptions: Sendable {

    // MARK: Lifecycle

    public init(
        name: String? = nil,
        country: String? = "US",
        state: String? = "AK",
        zone: String? = nil,
        source: GaugeSource? = .usgs,
        favorite: Bool? = nil,
        primary: Bool? = nil,
        boundingBox: BoundingBox? = nil) {
        self.name = name
        self.country = country
        self.state = state
        self.zone = zone
        self.source = source
        self.favorite = favorite
        self.primary = primary
        self.boundingBox = boundingBox
    }

    // MARK: Public

    public var name: String?
    public var country: String?
    public var state: String?
    public var zone: String?
    public var source: GaugeSource?
    public var favorite: Bool?
    public var primary: Bool?
    public var boundingBox: BoundingBox?

}

// MARK: - BoundingBox

public struct BoundingBox: Equatable, Sendable {
    public let minLatitude: Double
    public let maxLatitude: Double
    public let minLongitude: Double
    public let maxLongitude: Double

    public init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }
}

// MARK: - GaugeReadingQuery

public struct GaugeReadingQuery: Sendable {

    // MARK: Lifecycle

    public init(
        gaugeID: Gauge.ID,
        dateRange: DateInterval? = nil,
        metric: String? = nil,
        limit: Int? = nil) {
        self.gaugeID = gaugeID
        self.dateRange = dateRange
        self.metric = metric
        self.limit = limit
    }

    // MARK: Public

    public let gaugeID: Gauge.ID
    public let dateRange: DateInterval?
    public let metric: String?
    public let limit: Int?
}

// MARK: - GaugeReadingQuery Convenience

public extension GaugeReadingQuery {
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
            metric: metric)
    }

    /// Returns readings in the last N days
    static func lastDays(_ days: Int, gaugeID: Gauge.ID, metric: String? = nil) -> GaugeReadingQuery {
        let end = Date()
        let start = end.addingTimeInterval(-Double(days) * 86400)
        return GaugeReadingQuery(
            gaugeID: gaugeID,
            dateRange: DateInterval(start: start, end: end),
            metric: metric)
    }
}

// MARK: - DatabaseServiceError

public enum DatabaseServiceError: Error {
    case gaugeNotFound
    case unknownError
}

// Move outside the reducer to avoid MainActor isolation
private let forecastDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

// MARK: - ForecastDataPoint

public nonisolated struct ForecastDataPoint: Identifiable, Equatable, Sendable {

    public init(id: UUID = UUID(), index: Date, value: Double, lowerErrorBound: Double, upperErrorBound: Double) {
        self.id = id
        self.index = index
        self.value = value
        self.lowerErrorBound = lowerErrorBound
        self.upperErrorBound = upperErrorBound
    }

    public let id: UUID
    public let index: Date
    public let value: Double
    public let lowerErrorBound: Double
    public let upperErrorBound: Double
}

private nonisolated func parseForecastDate(_ index: String, year: Int, calendar: Calendar) -> Date? {
    let components = index.split(separator: "/")

    guard
        components.count == 2,
        let month = Int(components[0]),
        let day = Int(components[1])
    else {
        return nil
    }

    return calendar.date(from: DateComponents(year: year, month: month, day: day))
}

// MARK: - GaugeServiceError

public enum GaugeServiceError: Error {
    case unsupportedForecastReadingParam
}

private let logger = Logger(subsystem: "com.drewalth.GaugeWatcher", category: "GaugeService")

// MARK: - GaugeSource + GaugeDriverSource

extension GaugeSource {
    /// Converts a GaugeSource to a GaugeDriverSource
    var toDriverSource: GaugeDriverSource {
        switch self {
        case .usgs:
            return .usgs
        case .environmentCanada:
            return .environmentCanada
        case .lawa:
            return .lawa
        case .dwr:
            return .dwr
        }
    }
}
