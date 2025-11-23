//
//  DatabaseExt.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import SQLiteData
import GaugeSources
import Foundation

extension Database {
    func seedGaugeData(_ gaugeData: [GaugeSourceItem]) throws {
        // Filter out any items without a source before seeding
        let validGauges = gaugeData.filter { $0.source != nil }

        try seed {
            for (index, gauge) in validGauges.enumerated() {
                Gauge.Draft(
                    id: index + 1,
                    name: gauge.name,
                    siteID: gauge.siteID,
                    metric: gauge.metric,
                    country: gauge.country,
                    state: gauge.state,
                    zone: gauge.zone ?? "",
                    source: gauge.source!, // Safe because we filtered
                    latitude: Double(gauge.latitude),
                    longitude: Double(gauge.longitude),
                    updatedAt: .distantPast,
                    createdAt: .now)
            }
        }
    }
}

