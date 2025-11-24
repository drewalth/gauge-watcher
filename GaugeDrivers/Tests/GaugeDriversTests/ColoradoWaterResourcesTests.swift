//
//  ColoradoWaterResourcesTests.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Testing
@testable import GaugeDrivers

@Suite("ColoradoWaterResourcesTests")
struct ColoradoWaterResourcesTests {

    @Test("singleGaugeFetch")
    func singleGaugeFetch() async throws {
        let dwr = DWR()

        let siteIDs = ["5800777A", "0200616A"]

        for siteID in siteIDs {
            let results = try await dwr.fetchData(siteID)

            #expect(!results.isEmpty)
        }
    }

}
