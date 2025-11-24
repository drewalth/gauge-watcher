//
//  GaugeDrivers.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Foundation
import GaugeSources

// MARK: - GaugeDriver

/// Unified protocol that all gauge data source drivers must implement
public protocol GaugeDriver: Sendable {
    /// Fetches gauge readings with standardized options
    /// - Parameter options: Unified options that work across all drivers
    /// - Returns: Array of gauge readings
    /// - Throws: Driver-specific errors
    func fetchReadings(options: GaugeDriverOptions) async throws -> [GDGaugeReading]

    /// Fetches readings for multiple sites concurrently
    /// - Parameter optionsArray: Array of options for each site
    /// - Returns: Array of gauge readings from all sites
    /// - Throws: Driver-specific errors
    func fetchReadings(optionsArray: [GaugeDriverOptions]) async throws -> [GDGaugeReading]
}

// MARK: - GaugeDriverOptions

/// Unified options for fetching gauge data that work across all sources
public struct GaugeDriverOptions: Sendable {

    // MARK: Lifecycle

    public init(
        siteID: String,
        source: GaugeDriverSource,
        timePeriod: TimePeriod = .predefined(.last7Days),
        parameters: [ReadingParameter] = ReadingParameter.allCases,
        metadata: SourceMetadata? = nil) {
        self.siteID = siteID
        self.source = source
        self.timePeriod = timePeriod
        self.parameters = parameters
        self.metadata = metadata
    }

    // MARK: Public

    /// The site identifier for the gauge station
    public let siteID: String

    /// The data source (USGS, Environment Canada, etc.)
    public let source: GaugeDriverSource

    /// Time period for data retrieval (defaults to last 7 days)
    public let timePeriod: TimePeriod

    /// Which parameters to fetch (discharge, height, temperature)
    public let parameters: [ReadingParameter]

    /// Source-specific metadata (province for Canada, etc.)
    public let metadata: SourceMetadata?
}

// MARK: - GaugeDriverSource

public enum GaugeDriverSource: String, Codable, CaseIterable, Sendable {
    case usgs = "USGS"
    case environmentCanada = "ENVIRONMENT_CANADA"
    case lawa = "LAWA"
    case dwr = "DWR"
}

// MARK: - SourceMetadata

/// Container for source-specific metadata that doesn't apply universally
public enum SourceMetadata: Sendable {
    case environmentCanada(province: EnvironmentCanada.Province)
    // Add more as needed for other sources
}

// MARK: - ReadingParameter

/// Universal reading parameters that drivers should attempt to fetch
public enum ReadingParameter: String, CaseIterable, Sendable {
    case discharge // Flow rate
    case height // Stage/water level
    case temperature // Water temperature
}

// MARK: - TimePeriod

/// Represents a time range for fetching gauge data
public enum TimePeriod: Sendable, Equatable, Hashable {
    case predefined(PredefinedPeriod)
    case custom(start: Date, end: Date)

    // MARK: Public

    public enum PredefinedPeriod: Int, CaseIterable, Sendable, Hashable {
        case last24Hours = 1
        case last7Days = 7
        case last30Days = 30
        case last90Days = 90

        // MARK: Public

        public var description: String {
            switch self {
            case .last24Hours:
                return "Last 24 Hours"
            case .last7Days:
                return "Last 7 Days"
            case .last30Days:
                return "Last 30 Days"
            case .last90Days:
                return "Last 90 Days"
            }
        }

        public var stride: Int {
            switch self {
            case .last24Hours:
                return 1
            case .last7Days:
                return 2
            case .last30Days:
                return 8
            case .last90Days:
                return 12
            }
        }
    }

    public func stride(by timePeriod: TimePeriod) -> Int {
        switch timePeriod {
        case .predefined(let predefinedPeriod):
            return predefinedPeriod.stride
        case .custom(let start, let end):
            return Int(end.timeIntervalSince(start) / 60 * 60)
        }
    }
}

// MARK: - GaugeDriverFactory

/// Factory for creating the appropriate driver for a given source
public struct GaugeDriverFactory {

    // MARK: Lifecycle

    public init() { }

    // MARK: Public

    /// Returns the appropriate driver for the given source
    /// - Parameter source: The gauge data source
    /// - Returns: A driver instance that conforms to GaugeDriver protocol
    /// - Throws: GaugeDriverErrors.unsupportedSource if the source is not yet implemented
    public func driver(for source: GaugeDriverSource) throws -> any GaugeDriver {
        switch source {
        case .usgs:
            return GDUnitedStatesGeologicalSurvey()
        case .environmentCanada:
            return GDEnvironmentCanada()
        case .dwr:
            return GDColoradoDepartmentWaterResources()
        case .lawa:
            throw GaugeDriverErrors.unsupportedSource(source)
        }
    }

    /// Convenience method to fetch readings with a single call
    /// - Parameter options: Unified driver options
    /// - Returns: Array of gauge readings
    /// - Throws: GaugeDriverErrors if driver is unsupported or fetch fails
    public func fetchReadings(options: GaugeDriverOptions) async throws -> [GDGaugeReading] {
        let driver = try driver(for: options.source)
        return try await driver.fetchReadings(options: options)
    }

    /// Convenience method to fetch readings from multiple sites
    /// - Parameter optionsArray: Array of options for different sites
    /// - Returns: Array of all gauge readings
    /// - Throws: GaugeDriverErrors if any driver is unsupported or fetch fails
    public func fetchReadings(optionsArray: [GaugeDriverOptions]) async throws -> [GDGaugeReading] {
        // Group by source for efficient batch fetching
        let groupedBySource = Dictionary(grouping: optionsArray, by: { $0.source })

        var allReadings: [GDGaugeReading] = []

        try await withThrowingTaskGroup(of: [GDGaugeReading].self) { group in
            for (source, optionsForSource) in groupedBySource {
                let driver = try driver(for: source)
                group.addTask {
                    try await driver.fetchReadings(optionsArray: optionsForSource)
                }
            }

            for try await readings in group {
                allReadings.append(contentsOf: readings)
            }
        }

        return allReadings
    }
}

// MARK: - GaugeDriverErrors

public enum GaugeDriverErrors: Error, LocalizedError {
    case missingRequiredMetadata(String)
    case unsupportedParameter(ReadingParameter, GaugeDriverSource)
    case unsupportedSource(GaugeDriverSource)
    case invalidOptions(String)

    public var errorDescription: String? {
        switch self {
        case .missingRequiredMetadata(let detail):
            return "Missing required metadata: \(detail)"
        case .unsupportedParameter(let param, let source):
            return "Parameter '\(param.rawValue)' is not supported by \(source.rawValue)"
        case .unsupportedSource(let source):
            return "Source '\(source.rawValue)' is not yet implemented"
        case .invalidOptions(let detail):
            return "Invalid options: \(detail)"
        }
    }
}

// MARK: - GDGaugeReading

public struct GDGaugeReading: Codable, Identifiable, Sendable {
    public let id: UUID
    public let value: Double
    public let timestamp: Date
    public let unit: GaugeSourceMetric
    public let siteID: String

    public init(
        id: UUID,
        value: Double,
        timestamp: Date,
        unit: GaugeSourceMetric,
        siteID: String) {
        self.id = id
        self.value = value
        self.timestamp = timestamp
        self.unit = unit
        self.siteID = siteID
    }
}
