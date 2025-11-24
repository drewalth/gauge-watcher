import Foundation

// MARK: - GDGaugeReadingProtocol

public protocol GDGaugeReadingProtocol: Sendable {
    var id: UUID { get }
    var value: Double { get }
    var timestamp: Date { get }
    var unit: GDGaugeReadingUnit { get }
    var siteID: String { get }
}

// MARK: - GDGaugeReading

public struct GDGaugeReading: GDGaugeReadingProtocol {
    public let id: UUID
    public let value: Double
    public let timestamp: Date
    public let unit: GDGaugeReadingUnit
    public let siteID: String
}

// MARK: - GDGaugeReadingUnit

public enum GDGaugeReadingUnit: String, CaseIterable, Sendable {
    case cfs
    case feet
    case meter
    case cms
    case temperature
}

// MARK: - TimePeriod

public enum TimePeriod: Sendable {
    /// A custom time period with a start and end date.
    case custom(start: Date, end: Date)
    /// A predefined time period.
    /// - SeeAlso: `PredefinedTimePeriod`
    case predefined(PredefinedTimePeriod)
}

// MARK: - PredefinedTimePeriod

/// A predefined time period for fetching data from the USGS Water Services API.
/// With predefined time periods, you can fetch data for the last day, week, month, or year.
/// - Note: These values are used to get a date range from the current date.
public enum PredefinedTimePeriod: Int, CaseIterable, Sendable {
    case oneDay = 1
    case sevenDays = 7
    case thirtyDays = 30
    case oneYear = 365
}
