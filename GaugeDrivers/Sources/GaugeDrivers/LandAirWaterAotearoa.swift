//
//  LandAirWaterAotearoa.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Foundation
import GaugeSources
import os

public typealias LAWA = GDLandAirWaterAotearoa

// MARK: - GDLandAirWaterAotearoa

public struct GDLandAirWaterAotearoa: GaugeDriver, Sendable {

    // MARK: Lifecycle

    public init() { }

    // MARK: Public

    public enum Errors: Error, LocalizedError {
        case invalidURL
        case invalidData
        case decodingError
        case createDateError
        case invalidSampleDateTime(String)
        case invalidSiteID(String)

        // MARK: Public

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL for LAWA API"
            case .invalidData:
                return "Invalid data returned from LAWA API"
            case .decodingError:
                return "Failed to decode LAWA response"
            case .createDateError:
                return "Failed to parse date from LAWA response"
            case .invalidSiteID(let siteID):
                return "Invalid site ID for LAWA: \(siteID). Must be an integer."
            case .invalidSampleDateTime(let siteID):
                return "Invalid sample date time from site: \(siteID)"
            }
        }
    }

    // MARK: - GaugeDriver Protocol Conformance

    /// Unified API: Fetches readings using standardized options
    /// Note: LAWA API only supports fetching the latest single reading per site
    public func fetchReadings(options: GaugeDriverOptions) async -> Result<GaugeFetchResult, Error> {
        do {
            let readings = try await fetchLatestReading(siteID: options.siteID)
            
            let status = determineGaugeStatus(from: readings)
            
            let result = GaugeFetchResult(
                siteID: options.siteID,
                status: status,
                readings: readings)
            
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    /// Unified API: Fetches readings for multiple sites
    /// Note: LAWA API fetches each site individually (no batch endpoint)
    public func fetchReadings(optionsArray: [GaugeDriverOptions]) async -> Result<[GaugeFetchResult], Error> {
        var allResults: [GaugeFetchResult] = []

        do {
            try await withThrowingTaskGroup(of: (String, [GDGaugeReading]).self) { group in
                for options in optionsArray {
                    group.addTask {
                        let readings = try await fetchLatestReading(siteID: options.siteID)
                        return (options.siteID, readings)
                    }
                }

                for try await (siteID, readings) in group {
                    let status = determineGaugeStatus(from: readings)
                    
                    let result = GaugeFetchResult(
                        siteID: siteID,
                        status: status,
                        readings: readings)
                    
                    allResults.append(result)
                }
            }
            
            return .success(allResults)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Legacy/Direct API

    /// Fetches the latest reading from a LAWA gauge station
    /// - Parameter siteID: The site ID (pageId) as a string
    /// - Returns: Array with single latest reading
    /// - Throws: LAWA.Errors if fetch fails
    /// - Note: LAWA API only provides the latest single reading, no historical data
    public func fetchLatestReading(siteID: String) async throws -> [GDGaugeReading] {
        let urlString =
            "https://www.lawa.org.nz/umbraco/api/sensorservice/getLatestSample?pageId=\(siteID)&property=dischargeContinuous"

        guard let url = URL(string: urlString) else {
            throw Errors.invalidURL
        }

        let (data, _) = try await sharedSession.data(from: url)

        // Check if API returned null
        if
            let jsonString = String(data: data, encoding: .utf8),
            jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
            throw Errors.invalidSampleDateTime(siteID)
        }

        let sample = try decoder.decode(LatestFlowSample.self, from: data)

        // Check if we have valid data
        guard
            let dateStr = sample.date, let timeStr = sample.time,
            !dateStr.isEmpty, !timeStr.isEmpty,
            let valueStr = sample.value, !valueStr.isEmpty
        else {
            throw Errors.invalidSampleDateTime(siteID)
        }

        // Parse date: "11 Jul 2024 6:10 PM"
        let dateAndTime = "\(dateStr) \(timeStr)"

        logger.info("dateAndTime: \(dateAndTime)")
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy h:mm a"

        guard let date = formatter.date(from: dateAndTime) else {
            throw Errors.createDateError
        }

        // Convert string value to double
        guard let value = Double(valueStr) else {
            throw Errors.invalidData
        }

        // Parse unit string to GaugeSourceMetric
        let unit = parseUnit(sample.units ?? "CMS")

        let reading = GDGaugeReading(
            id: UUID(),
            value: value,
            timestamp: date,
            unit: unit,
            siteID: siteID)

        return [reading]
    }

    // MARK: Private

    private let decoder = JSONDecoder()
    private let logger = Logger(category: "LAWA")
    
    // MARK: - Status Detection
    
    /// Determines gauge status based on reading availability and timestamp
    /// LAWA provides only the latest reading, so we check if it's recent
    private func determineGaugeStatus(from readings: [GDGaugeReading]) -> GaugeStatus {
        guard !readings.isEmpty else {
            return .inactive
        }
        
        // LAWA only provides single latest reading, so check if it's recent (within 7 days)
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        
        let hasRecentReadings = readings.contains { reading in
            reading.timestamp >= sevenDaysAgo
        }
        
        return hasRecentReadings ? .active : .inactive
    }

    /// Converts LAWA unit string to GaugeSourceMetric
    private func parseUnit(_ unitString: String) -> GaugeSourceMetric {
        let normalized = unitString.uppercased().trimmingCharacters(in: .whitespaces)

        switch normalized {
        case "CMS", "M3/S", "M³/S":
            return .cms
        case "CFS", "FT3/S", "FT³/S":
            return .cfs
        case "M", "METERS", "METRES":
            return .meterHeight
        case "FT", "FEET":
            return .feetHeight
        default:
            logger.warning("Unknown unit '\(unitString)', defaulting to CMS")
            return .cms // Default to CMS for New Zealand
        }
    }
}

// MARK: GDLandAirWaterAotearoa.LatestFlowSample

extension GDLandAirWaterAotearoa {
    struct LatestFlowSample: Decodable {

        enum CodingKeys: String, CodingKey {
            case numericValue = "NumericValue"
            case value = "Value"
            case units = "Units"
            case dateTime = "DateTime"
            case date = "Date"
            case time = "Time"
            case error = "Error"
            case label = "Label"
            case cssClass = "CssClass"
            case compliance = "Compliance"
            case hasError = "HasError"
        }

        var numericValue: String?
        var value: String?
        var units: String?
        var dateTime: String?
        var date: String?
        var time: String?
        var error: String?
        var label: String?
        var cssClass: String?
        var compliance: String?
        var hasError: Bool?
    }
}
