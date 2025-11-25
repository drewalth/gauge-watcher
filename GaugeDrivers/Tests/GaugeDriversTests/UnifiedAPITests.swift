//
//  UnifiedAPITests.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Foundation
import Testing
@testable import GaugeDrivers

@Suite("Unified API Tests")
struct UnifiedAPITests {

    // MARK: - Factory Tests

    @Test("Factory: Driver selection for all sources")
    func factoryDriverSelection() {
        let factory = GaugeDriverFactory()

        // Test that factory returns correct driver types for all sources
        let usgsDriver = factory.driver(for: .usgs)
        #expect(usgsDriver is GDUnitedStatesGeologicalSurvey)

        let envCanadaDriver = factory.driver(for: .environmentCanada)
        #expect(envCanadaDriver is GDEnvironmentCanada)

        let dwrDriver = factory.driver(for: .dwr)
        #expect(dwrDriver is GDColoradoDepartmentWaterResources)

        let lawaDriver = factory.driver(for: .lawa)
        #expect(lawaDriver is GDLandAirWaterAotearoa)

        print("✅ Factory correctly returns driver types for all 4 sources")
    }

    // MARK: - Mixed Source Batch Fetching

    @Test("Mixed sources: USGS and Environment Canada batch fetch")
    func mixedSourceBatchFetch() async throws {
        let factory = GaugeDriverFactory()

        let optionsArray = [
            // USGS gauges
            GaugeDriverOptions(
                siteID: "09359500",
                source: .usgs,
                timePeriod: .predefined(.last24Hours),
                parameters: [.discharge]),
            GaugeDriverOptions(
                siteID: "01646500",
                source: .usgs,
                timePeriod: .predefined(.last24Hours),
                parameters: [.discharge]),
            // Environment Canada gauge
            GaugeDriverOptions(
                siteID: "07EA004",
                source: .environmentCanada,
                timePeriod: .predefined(.last24Hours),
                parameters: [.discharge],
                metadata: .environmentCanada(province: .bc))
        ]

        let results = try await factory.fetchReadings(optionsArray: optionsArray)

        #expect(!results.isEmpty)

        // Verify we got readings from all three gauges
        let usgs1Readings = results.filter { $0.siteID == "09359500" }
        let usgs2Readings = results.filter { $0.siteID == "01646500" }
        let envCanadaReadings = results.filter { $0.siteID == "07EA004" }

        #expect(!usgs1Readings.isEmpty)
        #expect(!usgs2Readings.isEmpty)
        #expect(!envCanadaReadings.isEmpty)

        // Verify correct units for each source
        #expect(usgs1Readings.allSatisfy { $0.unit == .cfs })
        #expect(usgs2Readings.allSatisfy { $0.unit == .cfs })
        // Environment Canada returns both cms (discharge) and meter (height)
        #expect(envCanadaReadings.allSatisfy { $0.unit == .cms || $0.unit == .meterHeight })

        print("✅ Mixed source batch fetch:")
        print("   USGS site 1: \(usgs1Readings.count) readings (cfs)")
        print("   USGS site 2: \(usgs2Readings.count) readings (cfs)")
        print("   Environment Canada: \(envCanadaReadings.count) readings (cms/meter)")
    }

    // MARK: - Time Period Tests

    @Test("Time periods: All predefined periods")
    func allPredefinedPeriods() async throws {
        let factory = GaugeDriverFactory()
        let siteID = "09359500"

        let periods: [TimePeriod] = [
            .predefined(.last24Hours),
            .predefined(.last7Days),
            .predefined(.last30Days),
            .predefined(.last90Days)
        ]

        for period in periods {
            let options = GaugeDriverOptions(
                siteID: siteID,
                source: .usgs,
                timePeriod: period,
                parameters: [.discharge])

            let results = try await factory.fetchReadings(options: options)

            #expect(!results.isEmpty)

            if case .predefined(let predefined) = period {
                print("✅ Time period \(predefined): \(results.count) readings")
            }
        }
    }

    @Test("Time periods: Custom date range")
    func customDateRange() async throws {
        let factory = GaugeDriverFactory()

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -6, to: endDate)!

        let options = GaugeDriverOptions(
            siteID: "09359500",
            source: .usgs,
            timePeriod: .custom(start: startDate, end: endDate),
            parameters: [.discharge])

        let results = try await factory.fetchReadings(options: options)

        #expect(!results.isEmpty)

        // Verify all readings are within the custom range
        for reading in results {
            #expect(reading.timestamp >= startDate)
            #expect(reading.timestamp <= endDate)
        }

        print("✅ Custom date range (6 hours): \(results.count) readings")
    }

    // MARK: - Parameter Tests

    @Test("Parameters: Single parameter")
    func singleParameter() async throws {
        let factory = GaugeDriverFactory()

        let dischargeOptions = GaugeDriverOptions(
            siteID: "09359500",
            source: .usgs,
            timePeriod: .predefined(.last24Hours),
            parameters: [.discharge])

        let dischargeResults = try await factory.fetchReadings(options: dischargeOptions)

        #expect(!dischargeResults.isEmpty)
        #expect(dischargeResults.allSatisfy { $0.unit == .cfs })

        print("✅ Single parameter (discharge): \(dischargeResults.count) readings")
    }

    @Test("Parameters: Multiple parameters")
    func multipleParameters() async throws {
        let factory = GaugeDriverFactory()

        let options = GaugeDriverOptions(
            siteID: "09359500",
            source: .usgs,
            timePeriod: .predefined(.last24Hours),
            parameters: [.discharge, .height, .temperature])

        let results = try await factory.fetchReadings(options: options)

        #expect(!results.isEmpty)

        // Should have mix of discharge, height, and possibly temperature
        let dischargeCount = results.filter { $0.unit == .cfs }.count
        let heightCount = results.filter { $0.unit == .feetHeight }.count

        #expect(dischargeCount > 0)
        #expect(heightCount > 0)

        print("✅ Multiple parameters:")
        print("   Discharge: \(dischargeCount) readings")
        print("   Height: \(heightCount) readings")
    }

    // MARK: - Error Handling Tests

    @Test("Error handling: Invalid site ID for LAWA")
    func errorInvalidLAWASiteID() async throws {
        let factory = GaugeDriverFactory()

        let options = GaugeDriverOptions(
            siteID: "not-a-number",
            source: .lawa,
            timePeriod: .predefined(.last24Hours),
            parameters: [.discharge])

        do {
            _ = try await factory.fetchReadings(options: options)
            Issue.record("Expected error for invalid LAWA siteID")
        } catch let error as LAWA.Errors {
            // Invalid site IDs return empty data from the API, which we catch as invalidSampleDateTime
            switch error {
            case .invalidSampleDateTime(let siteID):
                #expect(siteID == "not-a-number")
                print("✅ Error handling: Invalid LAWA site ID correctly caught (no data)")
            case .invalidSiteID(let siteID):
                #expect(siteID == "not-a-number")
                print("✅ Error handling: Invalid LAWA site ID correctly caught")
            default:
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("Error handling: Missing required metadata")
    func errorMissingMetadata() async throws {
        let factory = GaugeDriverFactory()

        // Environment Canada requires province metadata
        let options = GaugeDriverOptions(
            siteID: "07EA004",
            source: .environmentCanada,
            timePeriod: .predefined(.last24Hours),
            parameters: [.discharge]
            // No metadata provided
        )

        do {
            _ = try await factory.fetchReadings(options: options)
            Issue.record("Expected missing metadata error")
        } catch let error as GaugeDriverErrors {
            switch error {
            case .missingRequiredMetadata:
                print("✅ Error handling: Missing metadata correctly caught")
            default:
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - GaugeDriverOptions Tests

    @Test("GaugeDriverOptions: Default values")
    func optionsDefaultValues() {
        let options = GaugeDriverOptions(
            siteID: "09359500",
            source: .usgs)

        // Verify defaults
        #expect(options.timePeriod == .predefined(.last7Days))
        #expect(options.parameters == ReadingParameter.allCases)
        #expect(options.metadata == nil)

        print("✅ GaugeDriverOptions defaults applied correctly")
    }

    @Test("GaugeDriverOptions: Custom values")
    func optionsCustomValues() {
        let customPeriod = TimePeriod.predefined(.last30Days)
        let customParameters: [ReadingParameter] = [.discharge]
        let customMetadata = SourceMetadata.environmentCanada(province: .bc)

        let options = GaugeDriverOptions(
            siteID: "07EA004",
            source: .environmentCanada,
            timePeriod: customPeriod,
            parameters: customParameters,
            metadata: customMetadata)

        #expect(options.timePeriod == customPeriod)
        #expect(options.parameters == customParameters)
        #expect(options.metadata != nil)

        print("✅ GaugeDriverOptions custom values applied correctly")
    }
}
