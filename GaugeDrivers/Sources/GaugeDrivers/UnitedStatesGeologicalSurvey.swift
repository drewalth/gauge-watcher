//
//  UnitedStatesGeologicalSurvey.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Foundation
import os

public typealias USGS = GDUnitedStatesGeologicalSurvey

// MARK: - GDUnitedStatesGeologicalSurvey

public struct GDUnitedStatesGeologicalSurvey: GaugeDriver, Sendable {

    // MARK: Lifecycle

    public init() { }

    // MARK: Public
    
    // MARK: - GaugeDriver Protocol Conformance
    
    /// Unified API: Fetches readings using standardized options
    public func fetchReadings(options: GaugeDriverOptions) async throws -> [GDGaugeReading] {
        let parameters = options.parameters.compactMap { param -> USGSParameter? in
            switch param {
            case .discharge:
                return .discharge
            case .height:
                return .height
            case .temperature:
                return .temperature
            }
        }
        
        return try await fetchGaugeStationData(
            siteID: options.siteID,
            timePeriod: options.timePeriod,
            parameters: parameters
        )
    }
    
    /// Unified API: Fetches readings for multiple sites
    public func fetchReadings(optionsArray: [GaugeDriverOptions]) async throws -> [GDGaugeReading] {
        // Group by time period and parameters for efficient batching
        let grouped = Dictionary(grouping: optionsArray) { options in
            "\(options.timePeriod)-\(options.parameters.map { $0.rawValue }.joined())"
        }
        
        var allReadings: [GDGaugeReading] = []
        
        try await withThrowingTaskGroup(of: [GDGaugeReading].self) { group in
            for (_, optionsGroup) in grouped {
                guard let firstOptions = optionsGroup.first else { continue }
                
                let siteIDs = optionsGroup.map { $0.siteID }
                let parameters = firstOptions.parameters.compactMap { param -> USGSParameter? in
                    switch param {
                    case .discharge:
                        return .discharge
                    case .height:
                        return .height
                    case .temperature:
                        return .temperature
                    }
                }
                
                group.addTask {
                    try await self.fetchGaugeStationData(
                        for: siteIDs,
                        timePeriod: firstOptions.timePeriod,
                        parameters: parameters
                    )
                }
            }
            
            for try await readings in group {
                allReadings.append(contentsOf: readings)
            }
        }
        
        return allReadings
    }
    
    // MARK: - Legacy API (Deprecated but kept for backward compatibility)

    public enum USGSParameter: String, CaseIterable, Sendable {
        case discharge = "00060"
        case height = "00065"
        case temperature = "00010"
    }
    
    @available(*, deprecated, message: "Use fetchReadings(options:) instead")
    public enum ReadingParameter: String, CaseIterable, Sendable {
        case discharge = "00060"
        case height = "00065"
        case temperature = "00010"
    }

    // MARK: - Errors

    public enum Errors: Error, LocalizedError {
        case tooManySiteIDs
        case invalidDateRange
        case invalidURL
        case missingData
        case invalidParameter(String)
        case unableToAssociateParameterWithFKReadingUnit
        case unableToConvertStringToDate(String)
        case unableToConvertStringToDouble(String)

        // MARK: Public

        public var errorDescription: String? {
            switch self {
            case .tooManySiteIDs:
                "Too many site IDs provided. The USGS API has a limit of 100 site IDs per request."
            case .invalidDateRange:
                "The start date must be before the end date."
            case .invalidURL:
                "The URL is invalid."
            case .missingData:
                "The data returned from the USGS API is missing or incomplete."
            case .invalidParameter(let invalidParameter):
                "Invalid reading parameter: \(invalidParameter)"
            case .unableToAssociateParameterWithFKReadingUnit:
                "Unable to associate ReadingParameter with a FKReadingUnit."
            case .unableToConvertStringToDate(let string):
                "Unable to convert string to date: \(string)"
            case .unableToConvertStringToDouble(let string):
                "Unable to convert string to double: \(string)"
            }
        }
    }

    /// Fetches data from the USGS Water Services API for a single gauge station.
    /// - Parameters:
    ///  - siteID: The site ID of the gauge station.
    ///  - timePeriod: The time period for fetching data.
    ///  - parameters: The parameters to fetch.
    ///  - Returns: An array of `GDGaugeReading` objects.
    ///  - Throws: An error if the site ID is invalid, the date range is invalid, the URL is invalid, the data is missing, the parameter is invalid, or the string cannot be converted to a date or double.
    public func fetchGaugeStationData(
        siteID: String,
        timePeriod: TimePeriod,
        parameters: [USGSParameter])
    async throws -> [GDGaugeReading] {
        try await fetchData(for: [siteID], timePeriod: timePeriod, parameters: parameters)
    }

    /// Fetches data from the USGS Water Services API for multiple gauge stations.
    /// - Parameters:
    ///  - siteIDs: An array of site IDs for the gauge stations.
    ///  - timePeriod: The time period for fetching data.
    ///  - parameters: The parameters to fetch.
    ///  - Returns: An array of `GDGaugeReading` objects.
    ///  - Throws: An error if the site ID is invalid, the date range is invalid, the URL is invalid, the data is missing, the parameter is invalid, or the string cannot be converted to a date or double.
    ///  - Note: The USGS API has a limit of 100 site IDs per request. If you provide more than 100 site IDs, the function will split the requests into chunks of 100 site IDs each and fetch the data concurrently.
    public func fetchGaugeStationData(
        for siteIDs: [String],
        timePeriod: TimePeriod,
        parameters: [USGSParameter])
    async throws -> [GDGaugeReading] {
        let siteIDChunks = chunkedSiteIDs(array: siteIDs)

        var responseData: [GDGaugeReading] = []

        try await withThrowingTaskGroup(of: [GDGaugeReading].self) { group in
            for siteIDChunk in siteIDChunks {
                group.addTask {
                    try await fetchData(for: siteIDChunk, timePeriod: timePeriod, parameters: parameters)
                }
            }

            for try await readings in group {
                responseData.append(contentsOf: readings)
            }
        }

        return responseData
    }

    // MARK: Private

    private let logger = Logger(category: "USGS.WaterServices")

    // MARK: - fetchData

    private func fetchData(
        for siteIDs: [String],
        timePeriod: TimePeriod,
        parameters: [USGSParameter])
    async throws -> [GDGaugeReading] {
        if siteIDs.count > 100 {
            throw Errors.tooManySiteIDs
        }

        let baseURLString = "http://waterservices.usgs.gov/nwis/iv"

        let (start, end) = try getISO8601StartEnd(for: timePeriod)

        let queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "site", value: siteIDs.joined(separator: ",")),
            URLQueryItem(name: "parameterCd", value: parameters.map { $0.rawValue }.joined(separator: ",")),
            URLQueryItem(name: "startDT", value: start),
            URLQueryItem(name: "endDT", value: end)
        ]
        var urlComps = URLComponents(string: baseURLString)!
        urlComps.queryItems = queryItems

        guard let url = urlComps.url else {
            throw Errors.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        let decoder = JSONDecoder()
        let response = try decoder.decode(JSONResponse.self, from: data)

        var newReadings: [GDGaugeReading] = []

        for timeseries in response.value.timeSeries {
            guard
                let variable = timeseries.variable.variableCode.first?.value,
                let siteID = timeseries.sourceInfo.siteCode.first?.value
            else {
                throw Errors.missingData
            }

            guard let parameter = USGSParameter(rawValue: variable) else {
                throw Errors.invalidParameter(variable)
            }

            let unit: GDGaugeReadingUnit = switch parameter {
            case .discharge:
                .cfs
            case .height:
                .feet
            case .temperature:
                .temperature
            }

            for reading in timeseries.values {
                for readingValue in reading.value {
                    guard let createdAt = convertToDate(from: readingValue.dateTime) else {
                        throw Errors.unableToConvertStringToDate(readingValue.dateTime)
                    }

                    guard let value = Double(readingValue.value) else {
                        throw Errors.unableToConvertStringToDouble(readingValue.value)
                    }

                    newReadings.append(GDGaugeReading(
                                        id: UUID(),
                                        value: value,
                                        timestamp: createdAt,
                                        unit: unit,
                                        siteID: siteID))
                }
            }
        }

        return newReadings
    }

    private func convertToDate(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return formatter.date(from: string)
    }

    private func getISO8601StartEnd(for timePeriod: TimePeriod) throws -> (start: String, end: String) {
        let (start, end) = {
            switch timePeriod {
            case .custom(let customStart, let customEnd):
                return (customStart, customEnd)
            case .predefined(let period):
                let end = Date()
                let start = Calendar.current.date(byAdding: .day, value: -period.rawValue, to: end)!
                return (start, end)
            }
        }()

        if start > end {
            throw Errors.invalidDateRange
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Convert Date objects to ISO8601 formatted strings
        let endDateISO8601 = formatter.string(from: end)
        let startDateISO8601 = formatter.string(from: start)

        return (startDateISO8601, endDateISO8601)
    }

    private func chunkedSiteIDs<T>(array: [T]) -> [[T]] {
        /// The USGS API has a limit of 100 site IDs per request
        let size = 100

        return stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<Swift.min($0 + size, array.count)])
        }
    }
}

// MARK: GDUnitedStatesGeologicalSurvey.JSONResponse

extension GDUnitedStatesGeologicalSurvey {

    /// A response object containing the fetched data from the USGS Water Services API.
    public struct JSONResponse: Decodable {
        let name: String
        let declaredType: String
        let scope: String
        public let value: Value
        let nilValue: Bool
        let globalScope: Bool
        let typeSubstituted: Bool

        private enum CodingKeys: String, CodingKey {
            case name, declaredType, scope, value, nilValue = "nil", globalScope, typeSubstituted
        }

        public struct Value: Decodable {
            let queryInfo: QueryInfo
            public let timeSeries: [TimeSeries]
        }

        struct QueryInfo: Decodable {
            let queryURL: String
            let criteria: Criteria
            let note: [Note]
        }

        struct Criteria: Decodable {
            let locationParam: String
            let variableParam: String
            let parameter: [String]
        }

        struct Note: Decodable {
            let value: String
            let title: String
        }

        public struct TimeSeries: Decodable {
            public let sourceInfo: SourceInfo
            public let variable: Variable
            public let values: [ValueItem]
            let name: String
        }

        public struct SourceInfo: Decodable {
            let siteName: String
            public let siteCode: [SiteCode]
            let timeZoneInfo: TimeZoneInfo
            let geoLocation: GeoLocation
            let siteProperty: [SiteProperty]
        }

        public struct SiteCode: Decodable {
            public let value: String
            let network: String
            let agencyCode: String
        }

        struct TimeZoneInfo: Decodable {
            let defaultTimeZone: ZoneInfo
            let daylightSavingsTimeZone: ZoneInfo
            let siteUsesDaylightSavingsTime: Bool
        }

        struct ZoneInfo: Decodable {
            let zoneOffset: String
            let zoneAbbreviation: String
        }

        struct GeoLocation: Decodable {
            let geogLocation: GeogLocation
            let localSiteXY: [String]
        }

        struct GeogLocation: Decodable {
            let srs: String
            let latitude: Double
            let longitude: Double
        }

        struct SiteProperty: Decodable {
            let value: String
            let name: String
        }

        public struct Variable: Decodable {
            public let variableCode: [VariableCode]
            let variableName: String
            let variableDescription: String
            let valueType: String
            let unit: Unit
            let options: Options
            let noDataValue: Double
            let oid: String
        }

        public struct VariableCode: Decodable {
            public let value: String
            let network: String
            let vocabulary: String
            let variableID: Int
            let defaultFlag: Bool

            private enum CodingKeys: String, CodingKey {
                case value, network, vocabulary, variableID, defaultFlag = "default"
            }
        }

        struct Unit: Decodable {
            let unitCode: String
        }

        struct Options: Decodable {
            let option: [Option]
        }

        struct Option: Decodable {
            let name: String
            let optionCode: String
        }

        public struct ValueItem: Decodable {
            public let value: [ValueDetail]
            let qualifier: [Qualifier]
            let method: [Method]
        }

        public struct ValueDetail: Decodable {
            public let value: String
            public let qualifiers: [String]
            public let dateTime: String
        }

        struct Qualifier: Decodable {
            let qualifierCode: String
            let qualifierDescription: String
            let qualifierID: Int
            let network: String
            let vocabulary: String
        }

        struct Method: Decodable {
            let methodDescription: String
            let methodID: Int
        }
    }

}
