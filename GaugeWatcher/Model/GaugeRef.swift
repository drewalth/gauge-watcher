//
//  GaugeRef.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/1/25.
//
import AppDatabase
import CoreLocation
import Foundation
import GaugeSources

// MARK: - GaugeRef

/// Lightweight reference to a gauge
/// - Note: I added this because of threading issues related to SwiftData. Now that we're using SQLiteData, this may not be necessary.
nonisolated struct GaugeRef: Identifiable, Hashable, GaugeProtocol {
    let id: Int
    let name: String
    let siteID: String
    let metric: GaugeSourceMetric
    let country: String
    let state: String
    let zone: String
    let source: GaugeSource
    let favorite: Bool
    let primary: Bool
    let latitude: Double
    let longitude: Double
    let updatedAt: Date
    let createdAt: Date
}

// MARK: - Gauge + ref

extension Gauge {
    nonisolated var ref: GaugeRef {
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

// MARK: CustomStringConvertible

nonisolated extension GaugeRef: CustomStringConvertible {
    var description: String {
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
    var location: CLLocation {
        .init(latitude: latitude, longitude: longitude)
    }
}

extension GaugeRef {
    /// Checks if the gauge is stale by comparing the updatedAt date to the current date.
    /// If the updatedAt date is more than 30 minutes ago, the gauge is stale.
    nonisolated func isStale() -> Bool {
        let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
        return updatedAt < thirtyMinutesAgo
    }
}

extension GaugeRef {
    nonisolated var sourceURL: URL? {
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
