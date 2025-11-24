//
//  EnvironmentCanada.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Foundation
import os
// https://dd.weather.gc.ca/20251026/WXO-DD/hydrometric/csv/BC/hourly/BC_07EA004_hourly_hydrometric.csv
// MARK: - EnvironmentCanadaAPIProtocol

public protocol EnvironmentCanadaAPIProtocol {
    func fetchGaugeStationData(
        siteID: String,
        province: EnvironmentCanada.Province)
    async throws -> [GDGaugeReading]
    func fetchGaugeStationData(
        for siteIDs: [String],
        province: EnvironmentCanada.Province)
    async throws -> [GDGaugeReading]
}

public typealias EnvironmentCanada = GDEnvironmentCanada

// MARK: - GDEnvironmentCanada

public struct GDEnvironmentCanada: EnvironmentCanadaAPIProtocol, Sendable {

    // MARK: Lifecycle

    public init() { }

    // MARK: Public

    public enum Errors: Error, LocalizedError {
        case failedToFetch(Error)
        case invalidCSV(String)
        case invalidURL
        case failedToDownloadCSV(String)
        case failedToParseDate(String)
        case failedToParseWaterLevel(String)

        // MARK: Public

        public var errorDescription: String? {
            switch self {
            case .failedToFetch(let error):
                "Failed to fetch data: \(error.localizedDescription)"
            case .invalidCSV(let siteID):
                "Invalid CSV for siteID: \(siteID)"
            case .invalidURL:
                "Invalid URL Provided"
            case .failedToDownloadCSV(let siteID):
                "Failed to download CSV for siteID: \(siteID)"
            case .failedToParseDate(let siteID):
                "Failed to parse date for siteID: \(siteID)"
            case .failedToParseWaterLevel(let siteID):
                "Failed to parse water level for siteID: \(siteID)"
            }
        }

    }

    /// The province codes for the gauge stations
    public enum Province: String, CaseIterable, Sendable {
        case ab
        case bc
        case mb
        case nb
        case nl
        case ns
        case nt
        case nu
        case on
        case pe
        case qc
        case sk
        case yt
    }

    /// Fetches the latest readings for multiple gauge stations from the Environment Canada API concurrently.
    /// - Parameters:
    /// - siteIDs: An array of site IDs
    /// - province: The province code of the gauge stations
    /// - Returns: An array of FKReading objects
    /// - Throws: An error if the fetch fails
    public func fetchGaugeStationData(for siteIDs: [String], province: Province) async throws -> [GDGaugeReading] {
        var results = [GDGaugeReading]()

        try await withThrowingTaskGroup(of: [GDGaugeReading].self) { taskGroup in
            for siteID in siteIDs {
                taskGroup.addTask {
                    try await fetchData(siteID: siteID, province: province)
                }
            }

            for try await result in taskGroup {
                results.append(contentsOf: result)
            }
        }

        return results
    }

    /// Fetches the latest reading from the Environment Canada API
    /// - Parameters:
    ///  - siteID: The site ID of the gauge station
    ///  - province: The province code of the gauge station
    ///  - Returns: An array of FKReading objects
    ///  - Throws: An error if the fetch fails
    public func fetchGaugeStationData(siteID: String, province: Province) async throws -> [GDGaugeReading] {
        try await fetchData(siteID: siteID, province: province)
    }

    // MARK: Private

    private let logger = Logger(category: "EnvironmentCanadaAPI")

    /// Fetches the latest readings for a single gauge station from the Environment Canada API.
    /// - Parameters:
    /// - siteID: The site ID of the gauge station
    /// - province: The province code of the gauge station
    /// - Returns: An array of FKReading objects
    /// - Throws: An error if the fetch fails
    /// - Note: This function is private and should not be called directly.
    /// Use `fetchGaugeStationData(siteID:province:)` or `fetchGaugeStationData(for:province:)` instead.
    /// - Note: Canadian gauge readings are served as CSV files.
    private func fetchData(siteID: String, province: Province) async throws -> [GDGaugeReading] {
        let csvManager = CSVManager()
        let tempDirectory = try csvManager.createTempDirectory()
        do {
            var newReadings = [GDGaugeReading]()

            // Try current date first, then fall back to previous day if needed
            guard let url = try await buildURLWithFallback(siteID: siteID, province: province) else {
                throw Errors.invalidURL
            }

            logger.info("Fetching from: \(url.absoluteString)")
            
            guard let downloadedFileURL = try? await csvManager.downloadCSV(from: url) else {
                throw Errors.failedToDownloadCSV(url.absoluteString)
            }

            let tempFileURL = tempDirectory.appendingPathComponent(downloadedFileURL.lastPathComponent)
            try FileManager.default.moveItem(at: downloadedFileURL, to: tempFileURL)

            let parsedData = try csvManager.parseCSV(at: tempFileURL)

            guard csvManager.validateFirstRow(of: parsedData) else {
                throw Errors.invalidCSV(siteID)
            }

            for row in parsedData where row[0] == siteID {
                guard let createdAt = dateFromString(row[1]) else {
                    throw Errors.failedToParseDate(siteID)
                }

                guard let heightReading = Double(row[2]) else {
                    throw Errors.failedToParseWaterLevel(siteID)
                }

                guard let dischargeReading = Double(row[6]) else {
                    throw Errors.failedToParseWaterLevel(siteID)
                }

                newReadings.append(.init(id: .init(), value: heightReading, timestamp: createdAt, unit: .meter, siteID: siteID))
                newReadings.append(.init(id: .init(), value: dischargeReading, timestamp: createdAt, unit: .cms, siteID: siteID))
            }

            try csvManager.deleteTempDirectory(at: tempDirectory)
            return newReadings
        } catch {
            logger.error("Failed to fetch data for \(siteID): \(error.localizedDescription)")
            try csvManager.deleteTempDirectory(at: tempDirectory)
            throw Errors.failedToFetch(error)
        }
    }
    
    /// Builds the URL for the Environment Canada CSV file, trying current date first, then previous day.
    /// - Parameters:
    ///   - siteID: The site ID of the gauge station
    ///   - province: The province code of the gauge station
    /// - Returns: A valid URL if the file exists, nil otherwise
    private func buildURLWithFallback(siteID: String, province: Province) async throws -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(identifier: "America/Toronto") // Environment Canada uses Eastern Time
        
        // Try current date and previous day (in case today's file isn't published yet)
        for daysBack in 0...1 {
            let targetDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
            let dateString = dateFormatter.string(from: targetDate)
            
            let urlString = String(
                format: "https://dd.weather.gc.ca/%@/WXO-DD/hydrometric/csv/%@/hourly/%@_%@_hourly_hydrometric.csv",
                dateString,
                province.rawValue.uppercased(),
                province.rawValue.uppercased(),
                siteID)
            
            guard let url = URL(string: urlString) else { continue }
            
            // Quick HEAD request to check if URL exists before attempting full download
            if await urlExists(url) {
                return url
            }
            
            logger.info("File not found for date \(dateString), trying previous day...")
        }
        
        return nil
    }
    
    /// Checks if a URL exists by performing a HEAD request
    /// - Parameter url: The URL to check
    /// - Returns: true if the URL exists (returns 200), false otherwise
    private func urlExists(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

    private func dateFromString(_ dateString: String) -> Date? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone
        ]
        return dateFormatter.date(from: dateString)
    }
}

// MARK: - EnvironmentCanada.CSVManager

extension EnvironmentCanada {
    private struct CSVManager {

        // MARK: Internal

        func parseCSV(at url: URL) throws -> [[String]] {
            let content = try String(contentsOf: url)
            return content.components(separatedBy: "\n").map { $0.components(separatedBy: ",") }
        }

        /// Ensure that the downloaded CSV is not an HTML 404 page
        func validateFirstRow(of csvContent: [[String]]) -> Bool {
            csvContent[0].joined(separator: ",").replacingOccurrences(of: " ", with: "").contains("ID,Date,Water")
        }

        func downloadCSV(from url: URL) async throws -> URL {
            let (tempLocalURL, _) = try await URLSession.shared.download(from: url)
            return tempLocalURL
        }

        func createTempDirectory() throws -> URL {
            let tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            return tempDirectoryURL
        }

        func deleteTempDirectory(at url: URL) throws {
            try FileManager.default.removeItem(at: url)
        }

        // MARK: Private

        private let logger = Logger(category: "EnvironmentCanada.CSVManager")
    }
}
