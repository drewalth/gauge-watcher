//
//  GaugeRef.swift
//  SharedFeatures
//

import AppDatabase
import CoreLocation
import Foundation
import GaugeSources

// MARK: - GaugeRef

/// Lightweight reference to a gauge
/// - Note: I added this because of threading issues related to SwiftData. Now that we're using SQLiteData, this may not be necessary.
public nonisolated struct GaugeRef: Identifiable, Hashable, GaugeProtocol, Sendable {

    // MARK: Lifecycle

    public init(
        id: Int,
        name: String,
        siteID: String,
        metric: GaugeSourceMetric,
        country: String,
        state: String,
        zone: String,
        source: GaugeSource,
        favorite: Bool,
        primary: Bool,
        latitude: Double,
        longitude: Double,
        updatedAt: Date,
        createdAt: Date) {
        self.id = id
        self.name = name
        self.siteID = siteID
        self.metric = metric
        self.country = country
        self.state = state
        self.zone = zone
        self.source = source
        self.favorite = favorite
        self.primary = primary
        self.latitude = latitude
        self.longitude = longitude
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }

    // MARK: Public

    public let id: Int
    public let name: String
    public let siteID: String
    public let metric: GaugeSourceMetric
    public let country: String
    public let state: String
    public let zone: String
    public let source: GaugeSource
    public let favorite: Bool
    public let primary: Bool
    public let latitude: Double
    public let longitude: Double
    public let updatedAt: Date
    public let createdAt: Date

}

// MARK: - Gauge + ref

extension Gauge {
    public nonisolated var ref: GaugeRef {
        GaugeRef(
            id: id,
            name: name,
            siteID: siteID,
            metric: metric,
            country: country,
            state: state,
            zone: zone,
            source: source,
            favorite: favorite,
            primary: primary,
            latitude: latitude,
            longitude: longitude,
            updatedAt: updatedAt,
            createdAt: createdAt)
    }
}

// MARK: - GaugeRef + CustomStringConvertible

extension GaugeRef: CustomStringConvertible {
    public var description: String {
        """
    GaugeRef(
        id: \(id),
        name: \(name),
        siteID: \(siteID),
        metric: \(metric),
        country: \(country),
        state: \(state),
        zone: \(zone),
    """
    }
}

extension GaugeRef {
    public var location: CLLocation {
        .init(latitude: latitude, longitude: longitude)
    }
}

extension GaugeRef {
    /// Checks if the gauge is stale by comparing the updatedAt date to the current date.
    /// If the updatedAt date is more than 30 minutes ago, the gauge is stale.
    public nonisolated func isStale() -> Bool {
        let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
        return updatedAt < thirtyMinutesAgo
    }
}

extension GaugeRef {
    public nonisolated var sourceURL: URL? {
        var url: URL?
        switch source {
        case .usgs:
            url =
                URL(string: "https://waterdata.usgs.gov/monitoring-location/\(siteID)/#parameterCode=00065&period=P7D&showMedian=false")
        case .dwr:
            url = URL(string: "https://dwr.state.co.us/Tools/StationsLite/\(siteID)")
        default: break
        }
        if let url {
            return url
        }
        return nil
    }
}
