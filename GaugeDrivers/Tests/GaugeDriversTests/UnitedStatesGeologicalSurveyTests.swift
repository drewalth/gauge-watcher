//
//  UnitedStatesGeologicalSurveyTests.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Testing
@testable import GaugeDrivers

@Suite("UnitedStatesGeologicalSurveyTests")
struct UnitedStatesGeologicalSurveyTests {
    @Test
    func singleGaugeFetch() async throws {
        let results = try await USGS().fetchGaugeStationData(
            siteID: "09359500",
            timePeriod: .predefined(.sevenDays),
            parameters: [.height, .discharge])

        let latestDischarge = results.last { $0.unit == .cfs }
        let latestHeight = results.last { $0.unit == .feet }

        #expect(latestDischarge != nil)
        #expect(latestHeight != nil)

        print(latestDischarge!)
        print(latestHeight!)
    }

    @Test
    func multipleGaugeFetch() async throws {
        let results = try await USGS().fetchGaugeStationData(
            for: ["09359500", "01646500"],
            timePeriod: .predefined(.sevenDays),
            parameters: [.height, .discharge])

        let site1LatestDischarge = results.last { $0.siteID == "09359500" && $0.unit == .cfs }
        let site1LatestHeight = results.last { $0.siteID == "09359500" && $0.unit == .feet }

        let site2LatestDischarge = results.last { $0.siteID == "01646500" && $0.unit == .cfs }
        let site2LatestHeight = results.last { $0.siteID == "01646500" && $0.unit == .feet }

        #expect(site1LatestDischarge != nil)
        #expect(site1LatestHeight != nil)

        #expect(site2LatestDischarge != nil)
        #expect(site2LatestHeight != nil)

        print(site1LatestDischarge!)
        print(site1LatestHeight!)

        print(site2LatestDischarge!)
        print(site2LatestHeight!)
    }

}
