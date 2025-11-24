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

        let results = try await factory.fetchReadings(options: options)

        #expect(!results.isEmpty)

        let latestDischarge = results.last { $0.unit == .cms }
        let latestHeight = results.last { $0.unit == .meter }

        #expect(latestDischarge != nil)
        #expect(latestHeight != nil)

        print("✅ Unified API - Single Environment Canada gauge:")
        print("   Discharge: \(latestDischarge!.value) cms at \(latestDischarge!.timestamp)")
        print("   Height: \(latestHeight!.value) m at \(latestHeight!.timestamp)")
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

        let results = try await factory.fetchReadings(optionsArray: optionsArray)

        #expect(!results.isEmpty)

        let site1LatestDischarge = results.last { $0.siteID == "07EA004" && $0.unit == .cms }
        let site1LatestHeight = results.last { $0.siteID == "07EA004" && $0.unit == .meter }

        let site2LatestDischarge = results.last { $0.siteID == "07EA005" && $0.unit == .cms }
        let site2LatestHeight = results.last { $0.siteID == "07EA005" && $0.unit == .meter }

        #expect(site1LatestDischarge != nil)
        #expect(site1LatestHeight != nil)
        #expect(site2LatestDischarge != nil)
        #expect(site2LatestHeight != nil)

        print("✅ Unified API - Batch Environment Canada fetch:")
        print("   Site 1 (07EA004): \(site1LatestDischarge!.value) cms")
        print("   Site 2 (07EA005): \(site2LatestDischarge!.value) cms")
    }

    @Test("Unified API: Missing metadata error")
    func unifiedAPIMissingMetadata() async throws {
        let factory = GaugeDriverFactory()

        let options = GaugeDriverOptions(
            siteID: "07EA004",
            source: .environmentCanada,
            timePeriod: .predefined(.last24Hours),
            parameters: [.discharge, .height]
            // Note: No metadata provided - should throw error
        )

        do {
            _ = try await factory.fetchReadings(options: options)
            Issue.record("Expected error for missing metadata, but succeeded")
        } catch let error as GaugeDriverErrors {
            switch error {
            case .missingRequiredMetadata:
                print("✅ Unified API - Correctly throws error for missing metadata")
            default:
                Issue.record("Wrong error type: \(error)")
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
        let site1Results = try await factory.fetchReadings(options: site1Options)
        let site2Results = try await factory.fetchReadings(options: site2Options)

        #expect(!site1Results.isEmpty)
        #expect(!site2Results.isEmpty)

        print("✅ Unified API - Metadata correctly passed: \(site1Results.count + site2Results.count) total readings")
    }

    // MARK: - Legacy API Tests (Backward Compatibility)

    @Test("Legacy API: Single gauge fetch")
    func legacySingleGaugeFetch() async throws {
        let api = EnvironmentCanada()

        let results = try await api.fetchGaugeStationData(siteID: "07EA004", province: .bc)

        #expect(!results.isEmpty)

        let latestDischarge = results.last { $0.unit == .cms }
        let latestHeight = results.last { $0.unit == .meter }

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
