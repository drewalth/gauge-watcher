//
//  GaugeSourceItemDriverExt.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//
//  This file bridges GaugeSources metadata with GaugeDrivers fetching API

import Foundation
import GaugeSources
import GaugeDrivers

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

// MARK: - GaugeSourceItem + Driver Options

extension GaugeSourceItem {
    /// Creates driver options from this gauge source item
    /// - Parameters:
    ///   - timePeriod: Time period for data retrieval (defaults to last 7 days)
    ///   - parameters: Which parameters to fetch (defaults to all)
    /// - Returns: GaugeDriverOptions ready to use with the unified API
    func toDriverOptions(
        timePeriod: TimePeriod = .predefined(.last7Days),
        parameters: [ReadingParameter] = ReadingParameter.allCases
    ) -> GaugeDriverOptions? {
        guard let source = self.source else { return nil }
        
        let metadata: SourceMetadata? = {
            switch source {
            case .environmentCanada:
                // Map state code to province
                let provinceCode = state.lowercased()
                guard let province = EnvironmentCanada.Province(rawValue: provinceCode) else {
                    return nil
                }
                return .environmentCanada(province: province)
            case .usgs, .dwr, .lawa:
                return nil
            }
        }()
        
        return GaugeDriverOptions(
            siteID: siteID,
            source: source.toDriverSource,
            timePeriod: timePeriod,
            parameters: parameters,
            metadata: metadata
        )
    }
    
    /// Convenience method to fetch readings directly from this gauge source item
    /// - Parameters:
    ///   - timePeriod: Time period for data retrieval (defaults to last 7 days)
    ///   - parameters: Which parameters to fetch (defaults to all)
    ///   - factory: Optional custom factory (defaults to new instance)
    /// - Returns: Array of gauge readings
    /// - Throws: GaugeDriverErrors if options are invalid or fetch fails
    func fetchReadings(
        timePeriod: TimePeriod = .predefined(.last7Days),
        parameters: [ReadingParameter] = ReadingParameter.allCases,
        factory: GaugeDriverFactory = GaugeDriverFactory()
    ) async throws -> [GDGaugeReading] {
        guard let options = toDriverOptions(timePeriod: timePeriod, parameters: parameters) else {
            throw GaugeDriverErrors.invalidOptions("Unable to create driver options for gauge: \(name)")
        }
        return try await factory.fetchReadings(options: options)
    }
}

// MARK: - Array<GaugeSourceItem> + Batch Fetching

extension Array where Element == GaugeSourceItem {
    /// Convenience method to fetch readings for multiple gauge sources in parallel
    /// - Parameters:
    ///   - timePeriod: Time period for data retrieval (defaults to last 7 days)
    ///   - parameters: Which parameters to fetch (defaults to all)
    ///   - factory: Optional custom factory (defaults to new instance)
    /// - Returns: Array of all gauge readings from all sources
    /// - Throws: GaugeDriverErrors if any fetch fails
    func fetchReadings(
        timePeriod: TimePeriod = .predefined(.last7Days),
        parameters: [ReadingParameter] = ReadingParameter.allCases,
        factory: GaugeDriverFactory = GaugeDriverFactory()
    ) async throws -> [GDGaugeReading] {
        let optionsArray = self.compactMap { item in
            item.toDriverOptions(timePeriod: timePeriod, parameters: parameters)
        }
        
        guard !optionsArray.isEmpty else {
            throw GaugeDriverErrors.invalidOptions("No valid gauge source items to fetch")
        }
        
        return try await factory.fetchReadings(optionsArray: optionsArray)
    }
}

