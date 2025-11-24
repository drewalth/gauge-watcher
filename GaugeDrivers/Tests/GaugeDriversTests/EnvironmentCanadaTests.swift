//
//  EnvironmentCanadaTests.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Testing
@testable import GaugeDrivers

@Suite("EnvironmentCanadaTests")
struct EnvironmentCanadaTests {
    @Test("singleGaugeFetch")
    func singleGaugeFetch() async throws {
        let api = EnvironmentCanada()

        let results = try await api.fetchGaugeStationData(siteID: "07EA004", province: .bc)

        #expect(!results.isEmpty)

        let latestDischarge = results.last { $0.unit == .cms }
        let latestHeight = results.last { $0.unit == .meter }

        #expect(latestDischarge != nil)
        #expect(latestHeight != nil)

        print(latestDischarge!)
        print(latestHeight!)
    }

    @Test("multipleGaugeFetch")
    func multipleGaugeFetch() async throws {
        let api = EnvironmentCanada()

        let results = try await api.fetchGaugeStationData(for: ["07EA004", "07EA005"], province: .bc)

        #expect(!results.isEmpty)

        let site1LatestDischarge = results.last { $0.siteID == "07EA004" && $0.unit == .cms }
        let site1LatestHeight = results.last { $0.siteID == "07EA004" && $0.unit == .meter }

        let site2LatestDischarge = results.last { $0.siteID == "07EA005" && $0.unit == .cms }
        let site2LatestHeight = results.last { $0.siteID == "07EA005" && $0.unit == .meter }

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
