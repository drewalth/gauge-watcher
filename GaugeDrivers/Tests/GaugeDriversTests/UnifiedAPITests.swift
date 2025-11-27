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

        let result = await factory.fetchReadings(optionsArray: optionsArray)

        guard case .success(let fetchResults) = result else {
            if case .failure(let error) = result {
                Issue.record("Failed to fetch readings: \(error)")
            }
            return
        }

        #expect(!fetchResults.isEmpty)

        // Verify we got results from all three gauges
        let usgs1Result = fetchResults.first { $0.siteID == "09359500" }
        let usgs2Result = fetchResults.first { $0.siteID == "01646500" }
        let envCanadaResult = fetchResults.first { $0.siteID == "07EA004" }

        #expect(usgs1Result != nil)
        #expect(usgs2Result != nil)
        #expect(envCanadaResult != nil)

        // Verify correct units for each source
        if let usgs1 = usgs1Result {
            #expect(usgs1.readings.allSatisfy { $0.unit == .cfs })
            #expect(usgs1.status == .active || usgs1.status == .inactive)
        }
        if let usgs2 = usgs2Result {
            #expect(usgs2.readings.allSatisfy { $0.unit == .cfs })
            #expect(usgs2.status == .active || usgs2.status == .inactive)
        }
        if let envCanada = envCanadaResult {
            // Environment Canada returns both cms (discharge) and meter (height)
            #expect(envCanada.readings.allSatisfy { $0.unit == .cms || $0.unit == .meterHeight })
            #expect(envCanada.status == .active || envCanada.status == .inactive)
        }

        print("✅ Mixed source batch fetch:")
        print("   USGS site 1: \(usgs1Result?.readings.count ?? 0) readings, status: \(usgs1Result?.status.rawValue ?? "none")")
        print("   USGS site 2: \(usgs2Result?.readings.count ?? 0) readings, status: \(usgs2Result?.status.rawValue ?? "none")")
        print(
            "   Environment Canada: \(envCanadaResult?.readings.count ?? 0) readings, status: \(envCanadaResult?.status.rawValue ?? "none")")
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

            let result = await factory.fetchReadings(options: options)

            guard case .success(let fetchResult) = result else {
                if case .failure(let error) = result {
                    Issue.record("Failed to fetch readings: \(error)")
                }
                continue
            }

            #expect(!fetchResult.readings.isEmpty)

            if case .predefined(let predefined) = period {
                print("✅ Time period \(predefined): \(fetchResult.readings.count) readings, status: \(fetchResult.status.rawValue)")
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

        let result = await factory.fetchReadings(options: options)

        guard case .success(let fetchResult) = result else {
            if case .failure(let error) = result {
                Issue.record("Failed to fetch readings: \(error)")
            }
            return
        }

        #expect(!fetchResult.readings.isEmpty)

        // Verify all readings are within the custom range
        for reading in fetchResult.readings {
            #expect(reading.timestamp >= startDate)
            #expect(reading.timestamp <= endDate)
        }

        print("✅ Custom date range (6 hours): \(fetchResult.readings.count) readings, status: \(fetchResult.status.rawValue)")
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

        let result = await factory.fetchReadings(options: dischargeOptions)

        guard case .success(let fetchResult) = result else {
            if case .failure(let error) = result {
                Issue.record("Failed to fetch readings: \(error)")
            }
            return
        }

        #expect(!fetchResult.readings.isEmpty)
        #expect(fetchResult.readings.allSatisfy { $0.unit == .cfs })

        print("✅ Single parameter (discharge): \(fetchResult.readings.count) readings, status: \(fetchResult.status.rawValue)")
    }

    @Test("Parameters: Multiple parameters")
    func multipleParameters() async throws {
        let factory = GaugeDriverFactory()

        let options = GaugeDriverOptions(
            siteID: "09359500",
            source: .usgs,
            timePeriod: .predefined(.last24Hours),
            parameters: [.discharge, .height, .temperature])

        let result = await factory.fetchReadings(options: options)

        guard case .success(let fetchResult) = result else {
            if case .failure(let error) = result {
                Issue.record("Failed to fetch readings: \(error)")
            }
            return
        }

        #expect(!fetchResult.readings.isEmpty)

        // Should have mix of discharge, height, and possibly temperature
        let dischargeCount = fetchResult.readings.filter { $0.unit == .cfs }.count
        let heightCount = fetchResult.readings.filter { $0.unit == .feetHeight }.count

        #expect(dischargeCount > 0)
        #expect(heightCount > 0)

        print("✅ Multiple parameters:")
        print("   Discharge: \(dischargeCount) readings")
        print("   Height: \(heightCount) readings")
        print("   Status: \(fetchResult.status.rawValue)")
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

        let result = await factory.fetchReadings(options: options)

        switch result {
        case .success:
            Issue.record("Expected error for invalid LAWA siteID")
        case .failure(let error):
            if let lawaError = error as? LAWA.Errors {
                // Invalid site IDs return empty data from the API, which we catch as invalidSampleDateTime
                switch lawaError {
                case .invalidSampleDateTime(let siteID):
                    #expect(siteID == "not-a-number")
                    print("✅ Error handling: Invalid LAWA site ID correctly caught (no data)")
                case .invalidSiteID(let siteID):
                    #expect(siteID == "not-a-number")
                    print("✅ Error handling: Invalid LAWA site ID correctly caught")
                default:
                    Issue.record("Wrong error type: \(lawaError)")
                }
            } else {
                Issue.record("Expected LAWA.Errors but got: \(error)")
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

        let result = await factory.fetchReadings(options: options)

        switch result {
        case .success:
            Issue.record("Expected missing metadata error")
        case .failure(let error):
            if let driverError = error as? GaugeDriverErrors {
                switch driverError {
                case .missingRequiredMetadata:
                    print("✅ Error handling: Missing metadata correctly caught")
                default:
                    Issue.record("Wrong error type: \(driverError)")
                }
            } else {
                Issue.record("Expected GaugeDriverErrors but got: \(error)")
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
