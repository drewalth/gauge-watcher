//
//  EnvironmentCanadaTests.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Foundation
import Testing
@testable import GaugeDrivers

@Suite("EnvironmentCanadaTests")
struct EnvironmentCanadaTests {

    // MARK: - Unified API Tests

    @Test("Unified API: Single gauge fetch with metadata")
    func unifiedAPISingleGauge() async throws {
        let factory = GaugeDriverFactory()

        let options = GaugeDriverOptions(
            siteID: "07EA004",
            source: .environmentCanada,
            timePeriod: .predefined(.last24Hours),
            parameters: [.discharge, .height],
            metadata: .environmentCanada(province: .bc))

        let result = await factory.fetchReadings(options: options)
        
        guard case .success(let fetchResult) = result else {
            if case .failure(let error) = result {
                Issue.record("Failed to fetch readings: \(error)")
            }
            return
        }

        #expect(!fetchResult.readings.isEmpty)

        let latestDischarge = fetchResult.readings.last { $0.unit == .cms }
        let latestHeight = fetchResult.readings.last { $0.unit == .meterHeight }

        #expect(latestDischarge != nil)
        #expect(latestHeight != nil)

        print("✅ Unified API - Single Environment Canada gauge:")
        print("   Discharge: \(latestDischarge!.value) cms at \(latestDischarge!.timestamp)")
        print("   Height: \(latestHeight!.value) m at \(latestHeight!.timestamp)")
        print("   Status: \(fetchResult.status.rawValue)")
    }

    @Test("Unified API: Multiple gauge batch fetch")
    func unifiedAPIBatchFetch() async throws {
        let factory = GaugeDriverFactory()

        let optionsArray = [
            GaugeDriverOptions(
                siteID: "07EA004",
                source: .environmentCanada,
                timePeriod: .predefined(.last24Hours),
                parameters: [.discharge, .height],
                metadata: .environmentCanada(province: .bc)),
            GaugeDriverOptions(
                siteID: "07EA005",
                source: .environmentCanada,
                timePeriod: .predefined(.last24Hours),
                parameters: [.discharge, .height],
                metadata: .environmentCanada(province: .bc))
        ]

        let result = await factory.fetchReadings(optionsArray: optionsArray)
        
        guard case .success(let fetchResults) = result else {
            if case .failure(let error) = result {
                Issue.record("Failed to fetch readings: \(error)")
            }
            return
        }

        #expect(!fetchResults.isEmpty)

        let site1Result = fetchResults.first { $0.siteID == "07EA004" }
        let site2Result = fetchResults.first { $0.siteID == "07EA005" }

        #expect(site1Result != nil)
        #expect(site2Result != nil)

        if let site1 = site1Result {
            let latestDischarge = site1.readings.last { $0.unit == .cms }
            let latestHeight = site1.readings.last { $0.unit == .meterHeight }
            
            #expect(latestDischarge != nil)
            #expect(latestHeight != nil)
            
            print("✅ Unified API - Batch Environment Canada fetch:")
            print("   Site 1 (07EA004): \(latestDischarge!.value) cms, status: \(site1.status.rawValue)")
        }
        
        if let site2 = site2Result {
            let latestDischarge = site2.readings.last { $0.unit == .cms }
            #expect(latestDischarge != nil)
            print("   Site 2 (07EA005): \(latestDischarge!.value) cms, status: \(site2.status.rawValue)")
        }
    }

    @Test("Unified API: Missing metadata error")
    func unifiedAPIMissingMetadata() async throws {
        let factory = GaugeDriverFactory()

        let options = GaugeDriverOptions(
            siteID: "07EA004",
            source: .environmentCanada,
            timePeriod: .predefined(.last24Hours),
            parameters: [.discharge, .height]
            // Note: No metadata provided - should return error
        )

        let result = await factory.fetchReadings(options: options)
        
        switch result {
        case .success:
            Issue.record("Expected error for missing metadata, but succeeded")
        case .failure(let error):
            if let driverError = error as? GaugeDriverErrors {
                switch driverError {
                case .missingRequiredMetadata:
                    print("✅ Unified API - Correctly returns error for missing metadata")
                default:
                    Issue.record("Wrong error type: \(driverError)")
                }
            } else {
                Issue.record("Expected GaugeDriverErrors but got: \(error)")
            }
        }
    }

    @Test("Unified API: Metadata correctly passed through")
    func unifiedAPIMetadataPassthrough() async throws {
        let factory = GaugeDriverFactory()

        // Test that metadata is correctly used by trying two different BC sites
        let site1Options = GaugeDriverOptions(
            siteID: "07EA004",
            source: .environmentCanada,
            timePeriod: .predefined(.last24Hours),
            parameters: [.discharge],
            metadata: .environmentCanada(province: .bc))

        let site2Options = GaugeDriverOptions(
            siteID: "07EA005",
            source: .environmentCanada,
            timePeriod: .predefined(.last24Hours),
            parameters: [.discharge],
            metadata: .environmentCanada(province: .bc))

        // Verify both work with the same metadata
        let site1Result = await factory.fetchReadings(options: site1Options)
        let site2Result = await factory.fetchReadings(options: site2Options)

        guard case .success(let site1FetchResult) = site1Result,
              case .success(let site2FetchResult) = site2Result else {
            Issue.record("Failed to fetch one or both sites")
            return
        }

        #expect(!site1FetchResult.readings.isEmpty)
        #expect(!site2FetchResult.readings.isEmpty)

        print("✅ Unified API - Metadata correctly passed: \(site1FetchResult.readings.count + site2FetchResult.readings.count) total readings")
    }

    // MARK: - Legacy API Tests (Backward Compatibility)

    @Test("Legacy API: Single gauge fetch")
    func legacySingleGaugeFetch() async throws {
        let api = EnvironmentCanada()

        let results = try await api.fetchGaugeStationData(siteID: "07EA004", province: .bc)

        #expect(!results.isEmpty)

        let latestDischarge = results.last { $0.unit == .cms }
        let latestHeight = results.last { $0.unit == .meterHeight }

        #expect(latestDischarge != nil)
        #expect(latestHeight != nil)

        print("✅ Legacy API - Single gauge: Works")
    }

    @Test("Legacy API: Multiple gauge fetch")
    func legacyMultipleGaugeFetch() async throws {
        let api = EnvironmentCanada()

        let results = try await api.fetchGaugeStationData(for: ["07EA004", "07EA005"], province: .bc)

        #expect(!results.isEmpty)

        let site1LatestDischarge = results.last { $0.siteID == "07EA004" && $0.unit == .cms }
        let site2LatestDischarge = results.last { $0.siteID == "07EA005" && $0.unit == .cms }

        #expect(site1LatestDischarge != nil)
        #expect(site2LatestDischarge != nil)

        print("✅ Legacy API - Multiple gauges: Works")
    }
}
