//
//  GaugeInfo.swift
//  SharedFeatures
//
//  Created by Andrew Althage on 12/18/25.
//

// MARK: - GaugeInfo

/// Simplified gauge representation for LLM tool output
struct GaugeInfo: Codable, Sendable {

    // MARK: Lifecycle

    init(from gauge: GaugeRef) {
        id = gauge.id
        name = gauge.name
        siteID = gauge.siteID
        country = gauge.country
        state = gauge.state
        source = gauge.source.rawValue
        latitude = gauge.latitude
        longitude = gauge.longitude
        isFavorite = gauge.favorite
        lastUpdated = gauge.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: Internal

    let id: Int
    let name: String
    let siteID: String
    let country: String
    let state: String
    let source: String
    let latitude: Double
    let longitude: Double
    let isFavorite: Bool
    let lastUpdated: String

}
