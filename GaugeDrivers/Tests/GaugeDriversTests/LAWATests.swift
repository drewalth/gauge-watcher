//
//  LAWATests.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import GaugeSources
import os.log
import Testing
@testable import GaugeDrivers

@Suite("LAWA Tests")
struct LAWATests {
    @Test
    func fetchReading() async throws {
        let factory = GaugeDriverFactory()
        // 29960
        let opts = GaugeDriverOptions(
            siteID: "30187",
            source: .lawa,
            timePeriod: .predefined(.last24Hours),
            parameters: [.height, .discharge])

        let result = await factory.fetchReadings(options: opts)

        guard case .success(let fetchResult) = result else {
            if case .failure(let error) = result {
                Issue.record("Failed to fetch readings: \(error)")
            }
            return
        }

        print(fetchResult)

        #expect(!fetchResult.readings.isEmpty)
        print("✅ LAWA fetch: \(fetchResult.readings.count) readings, status: \(fetchResult.status.rawValue)")
    }

    @Test(.disabled("We don't need to run these all the time"))
    func validateAllGauges() async throws {
        let sources = try await GaugeSources.loadAllNZ()
        #expect(sources.count == 33)
        #expect(sources.allSatisfy { $0.source == .lawa })
        #expect(sources.allSatisfy { $0.country == "NZ" })

        // fetch latest reading for each gauge
        for source in sources {
            let factory = GaugeDriverFactory()
            let opts = GaugeDriverOptions(
                siteID: source.siteID,
                source: .lawa,
                timePeriod: .predefined(.last24Hours),
                parameters: [.discharge])
            let result = await factory.fetchReadings(options: opts)
            
            guard case .success(let fetchResult) = result else {
                if case .failure(let error) = result {
                    print("⚠️ Failed to fetch \(source.siteID): \(error)")
                }
                continue
            }
            
            #expect(!fetchResult.readings.isEmpty)
        }
    }
}
