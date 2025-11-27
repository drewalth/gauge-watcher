//
//  UnitedStatesGeologicalSurveyTests.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Foundation
import Testing
@testable import GaugeDrivers

@Suite("UnitedStatesGeologicalSurveyTests")
struct UnitedStatesGeologicalSurveyTests {

    // MARK: - Unified API Tests

    @Test("Unified API: Single gauge fetch")
    func unifiedAPISingleGauge() async throws {
        let factory = GaugeDriverFactory()

        let options = GaugeDriverOptions(
            siteID: "09359500",
            source: .usgs,
            timePeriod: .predefined(.last7Days),
            parameters: [.discharge, .height])

        let result = await factory.fetchReadings(options: options)

        guard case .success(let fetchResult) = result else {
            if case .failure(let error) = result {
                Issue.record("Failed to fetch readings: \(error)")
            }
            return
        }

        #expect(!fetchResult.readings.isEmpty)

        let latestDischarge = fetchResult.readings.last { $0.unit == .cfs }
        let latestHeight = fetchResult.readings.last { $0.unit == .feetHeight }

        #expect(latestDischarge != nil)
        #expect(latestHeight != nil)

        print("✅ Unified API - Single USGS gauge:")
        print("   Discharge: \(latestDischarge!.value) cfs at \(latestDischarge!.timestamp)")
        print("   Height: \(latestHeight!.value) ft at \(latestHeight!.timestamp)")
        print("   Status: \(fetchResult.status.rawValue)")
    }

    @Test("Unified API: Multiple gauge batch fetch")
    func unifiedAPIBatchFetch() async throws {
        let factory = GaugeDriverFactory()

        let optionsArray = [
            GaugeDriverOptions(
                siteID: "09359500",
                source: .usgs,
                timePeriod: .predefined(.last7Days),
                parameters: [.discharge, .height]),
            GaugeDriverOptions(
                siteID: "01646500",
                source: .usgs,
                timePeriod: .predefined(.last7Days),
                parameters: [.discharge, .height])
        ]

        let result = await factory.fetchReadings(optionsArray: optionsArray)

        guard case .success(let fetchResults) = result else {
            if case .failure(let error) = result {
                Issue.record("Failed to fetch readings: \(error)")
            }
            return
        }

        #expect(!fetchResults.isEmpty)

        let site1Result = fetchResults.first { $0.siteID == "09359500" }
        let site2Result = fetchResults.first { $0.siteID == "01646500" }

        #expect(site1Result != nil)
        #expect(site2Result != nil)

        if let site1 = site1Result {
            let latestDischarge = site1.readings.last { $0.unit == .cfs }
            let latestHeight = site1.readings.last { $0.unit == .feetHeight }

            #expect(latestDischarge != nil)
            #expect(latestHeight != nil)

            print("✅ Unified API - Batch USGS fetch:")
            print("   Site 1 (09359500): \(latestDischarge!.value) cfs, status: \(site1.status.rawValue)")
        }

        if let site2 = site2Result {
            let latestDischarge = site2.readings.last { $0.unit == .cfs }
            #expect(latestDischarge != nil)
            print("   Site 2 (01646500): \(latestDischarge!.value) cfs, status: \(site2.status.rawValue)")
        }
    }

    @Test("Unified API: Custom time period")
    func unifiedAPICustomTimePeriod() async throws {
        let factory = GaugeDriverFactory()

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -3, to: endDate)!

        let options = GaugeDriverOptions(
            siteID: "09359500",
            source: .usgs,
            timePeriod: .custom(start: startDate, end: endDate),
            parameters: [.discharge])

        let result = await factory.fetchReadings(options: options)

        guard case .success(let fetchResult) = result else {
            if case .failure(let error) = result {
                Issue.record("Failed to fetch readings: \(error)")
            }
            return
        }

        #expect(!fetchResult.readings.isEmpty)

        // Verify all results are within the date range
        for reading in fetchResult.readings {
            #expect(reading.timestamp >= startDate)
            #expect(reading.timestamp <= endDate)
        }

        print(
            "✅ Unified API - Custom time period (3 days): \(fetchResult.readings.count) readings, status: \(fetchResult.status.rawValue)")
    }

    @Test("Unified API: Single parameter fetch")
    func unifiedAPISingleParameter() async throws {
        let factory = GaugeDriverFactory()

        let options = GaugeDriverOptions(
            siteID: "09359500",
            source: .usgs,
            timePeriod: .predefined(.last24Hours),
            parameters: [.discharge])

        let result = await factory.fetchReadings(options: options)

        guard case .success(let fetchResult) = result else {
            if case .failure(let error) = result {
                Issue.record("Failed to fetch readings: \(error)")
            }
            return
        }

        #expect(!fetchResult.readings.isEmpty)

        // Should only have discharge readings
        #expect(fetchResult.readings.allSatisfy { $0.unit == .cfs })

        print(
            "✅ Unified API - Single parameter (discharge): \(fetchResult.readings.count) readings, status: \(fetchResult.status.rawValue)")
    }

    // MARK: - Legacy API Tests (Backward Compatibility)

    @Test("Legacy API: Single gauge fetch")
    func legacySingleGaugeFetch() async throws {
        let results = try await USGS().fetchGaugeStationData(
            siteID: "09359500",
            timePeriod: .predefined(.last7Days),
            parameters: [.height, .discharge])

        let latestDischarge = results.last { $0.unit == .cfs }
        let latestHeight = results.last { $0.unit == .feetHeight }

        #expect(latestDischarge != nil)
        #expect(latestHeight != nil)

        print("✅ Legacy API - Single gauge: Works")
    }

    @Test("Legacy API: Multiple gauge fetch")
    func legacyMultipleGaugeFetch() async throws {
        let results = try await USGS().fetchGaugeStationData(
            for: ["09359500", "01646500"],
            timePeriod: .predefined(.last7Days),
            parameters: [.height, .discharge])

        let site1LatestDischarge = results.last { $0.siteID == "09359500" && $0.unit == .cfs }
        let site2LatestDischarge = results.last { $0.siteID == "01646500" && $0.unit == .cfs }

        #expect(site1LatestDischarge != nil)
        #expect(site2LatestDischarge != nil)

        print("✅ Legacy API - Multiple gauges: Works")
    }
}
