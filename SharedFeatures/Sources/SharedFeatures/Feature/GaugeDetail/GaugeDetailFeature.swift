//
//  GaugeDetailFeature.swift
//  SharedFeatures
//

import ComposableArchitecture
import Foundation
import GaugeDrivers
import GaugeService
import GaugeSources
import Loadable
import MapKit
import os
import StoreKit
import Cocoa

// MARK: - GaugeDetailFeature

@Reducer
public struct GaugeDetailFeature: Sendable {

    // MARK: Lifecycle

    // MARK: - Initializer

    public init() { }

    // MARK: Public

    // MARK: - State

    @ObservableState
    public struct State {
        public var gaugeID: Int
        public var gauge: Loadable<GaugeRef> = .initial
        public var readings: Loadable<[GaugeReadingRef]> = .initial
        public var selectedTimePeriod: TimePeriod.PredefinedPeriod = .last7Days
        public var availableMetrics: [GaugeSourceMetric]?
        public var selectedMetric: GaugeSourceMetric?
        public var forecast: Loadable<[ForecastDataPoint]> = .initial
        public var forecastAvailable: Loadable<Bool> = .initial
        public var forecastInfoSheetPresented = false
        public var infoSheetPresented = false
        @Shared(.appStorage("app-review-requested-01")) public var appReviewRequested = false

        public init(_ gaugeID: Int) {
            self.gaugeID = gaugeID
        }
    }

    // MARK: - Action

    public enum Action {
        case load
        case setGauge(Loadable<GaugeRef>)
        case sync
        case loadReadings
        case setReadings(Loadable<[GaugeReadingRef]>)
        case setSelectedTimePeriod(TimePeriod.PredefinedPeriod)
        case setAvailableMetrics([GaugeSourceMetric])
        case setSelectedMetric(GaugeSourceMetric)
        case toggleFavorite
        case openSource
        case getForecast
        case setForecast(Loadable<[ForecastDataPoint]>)
        case setForecastAvailable(Loadable<Bool>)
        case setForecastInfoSheetPresented(Bool)
        case setInfoSheetPresented(Bool)
        case openInMaps
        case setAppReviewRequested(Bool)
        case requestAppReview
    }

    // MARK: - CancelID

    nonisolated public enum CancelID: Sendable {
        case sync
        case loadReadings
        case load
    }
    
    @Dependency(\.continuousClock) var clock

    // MARK: - Body

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .requestAppReview:
                guard !state.appReviewRequested else {
                    return .none
                }

                return .run { send in
                    await send(.setAppReviewRequested(true))
                    do {
                        try await clock.sleep(for: .seconds(1))
                        AppReviewManager.promptForReview()
                      
                    } catch {
                        logger.error("\(error.localizedDescription)")
                    }
                    
                    
                }
            case .setAppReviewRequested(let newValue):
                state.$appReviewRequested.withLock { $0 = newValue }
                return .none
            case .openInMaps:
                guard let gauge = state.gauge.unwrap() else {
                    return .none
                }
                let coordinate = gauge.location.coordinate
                let regionDistance: CLLocationDistance = 1000
                let regionSpan = MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: regionDistance,
                    longitudinalMeters: regionDistance)
                let options = [
                    MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
                    MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
                ]

                let placemark = MKPlacemark(coordinate: coordinate)
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = gauge.name
                mapItem.openInMaps(launchOptions: options)
                return .none
            case .setInfoSheetPresented(let newValue):
                state.infoSheetPresented = newValue
                return .none
            case .setForecastInfoSheetPresented(let newValue):
                state.forecastInfoSheetPresented = newValue
                return .none
            case .setForecastAvailable(let newValue):
                state.forecastAvailable = newValue
                return .none

            case .setForecast(let newValue):
                state.forecast = newValue
                return .none

            case .getForecast:
                guard
                    let gauge = state.gauge.unwrap(),
                    gauge.source == .usgs
                else {
                    state.forecastAvailable = .loaded(false)
                    return .none
                }

                return .run { [gauge = state.gauge, logger] send in
                    do {
                        guard
                            let gauge = gauge.unwrap(),
                            gauge.source == .usgs
                        else {
                            logger.info("Forecast not available")
                            return
                        }

                        @Dependency(\.gaugeService) var gaugeService
                        let result = try await gaugeService.forecast(gauge.siteID, USGS.USGSParameter.discharge)

                        await send(.setForecast(.loaded(result)))
                    } catch {
                        logger.error("Forecast error: \(error.localizedDescription)")
                        await send(.setForecast(.error(error)))
                    }
                }

            case .openSource:
                return .run { [gauge = state.gauge, logger] _ in
                    do {
                        guard
                            let gaugeRef = gauge.unwrap(),
                            let sourceURL = gaugeRef.sourceURL
                        else {
                            throw Errors.invalidGaugeSourceURL
                        }

                        @Dependency(\.webBrowserService) var webBrowserService
                        try await webBrowserService.open(sourceURL, WebBrowserOptions())

                    } catch {
                        logger.error("\(#function): \(error.localizedDescription)")
                    }
                }

            case .toggleFavorite:
                guard state.gauge.unwrap() != nil else {
                    return .none
                }
                return .concatenate(
                    .run { [gaugeID = state.gaugeID] _ in
                        @Dependency(\.gaugeService) var gaugeService
                        try await gaugeService.toggleFavorite(gaugeID)
                    }, .send(.load), .send(.requestAppReview))

            case .setAvailableMetrics(let newValue):
                state.availableMetrics = newValue
                return .none

            case .setSelectedMetric(let newValue):
                state.selectedMetric = newValue
                return .none

            case .setSelectedTimePeriod(let newValue):
                state.selectedTimePeriod = newValue
                return .none

            case .setReadings(let newValue):
                state.readings = newValue
                return .none

            case .loadReadings:
                // If we already have readings, show them while reloading. Otherwise, show loading.
                if state.readings.isLoaded() {
                    state.readings = .reloading(state.readings.unwrap()!)
                } else {
                    state.readings = .loading
                }

                return .run { [gaugeID = state.gaugeID] send in
                    do {
                        @Dependency(\.gaugeService) var gaugeService
                        let readings = try await gaugeService.loadGaugeReadings(.init(gaugeID: gaugeID)).map { $0.ref }
                        let availableMetrics = getAvailableMetrics(for: readings)

                        await send(.setAvailableMetrics(availableMetrics))
                        if let selectedMetric = availableMetrics.first {
                            await send(.setSelectedMetric(selectedMetric))
                        }
                        await Task.yield()
                        await send(.setReadings(.loaded(readings)))

                    } catch {
                        await send(.setReadings(.error(error)))
                    }
                }.cancellable(id: CancelID.loadReadings, cancelInFlight: true)

            case .sync:
                guard let gauge = state.gauge.unwrap() else {
                    logger.warning("gauge not set in state")
                    return .none
                }

                state.gauge = .reloading(gauge)
                if state.readings.isLoaded() {
                    state.readings = .reloading(state.readings.unwrap()!)
                } else {
                    state.readings = .loading
                }
                return .run { [gaugeID = state.gaugeID] send in
                    do {
                        @Dependency(\.gaugeService) var gaugeService
                        // Sync with API
                        try await gaugeService.sync(gaugeID)

                        // Reload gauge from database after sync
                        let updatedGauge = try await gaugeService.loadGauge(gaugeID).ref
                        await send(.setGauge(.loaded(updatedGauge)))

                        // Now load readings
                        await send(.loadReadings)
                    } catch {
                        await send(.setGauge(.error(error)))
                        await send(.setReadings(.error(error)))
                    }
                }.cancellable(id: CancelID.sync, cancelInFlight: false)

            case .setGauge(let newValue):
                state.gauge = newValue
                return .none

            case .load:
                if state.gauge.isLoaded() {
                    state.gauge = .reloading(state.gauge.unwrap()!)
                } else if state.gauge.isInitial() {
                    state.gauge = .loading
                }
                return .run { [gaugeID = state.gaugeID, logger] send in
                    do {
                        @Dependency(\.gaugeService) var gaugeService
                        let gauge = try await gaugeService.loadGauge(gaugeID).ref

                        await send(.setGauge(.loaded(gauge)))

                        if gauge.source == .usgs {
                            await send(.setForecastAvailable(.loaded(true)))
                        }

                        if gauge.isStale() {
                            logger.info("syncing gauge")
                            await send(.sync)
                        } else {
                            // Only load readings if we're not syncing (sync will load them after)
                            await send(.loadReadings)
                        }

                    } catch {
                        await send(.setGauge(.error(error)))
                    }
                }.cancellable(id: CancelID.load, cancelInFlight: true)
            }
        }
    }

    // MARK: Private

    private let logger = Logger(category: "GaugeDetailFeature")

    // MARK: - Private Helpers

    private nonisolated func getAvailableMetrics(for readings: [GaugeReadingRef]) -> [GaugeSourceMetric] {
        // Use Set to get unique metrics, then convert back to array
        let uniqueMetrics = Set(readings.compactMap { GaugeSourceMetric(rawValue: $0.metric.uppercased()) })
        return Array(uniqueMetrics).sorted { $0.rawValue < $1.rawValue }
    }
}

// MARK: GaugeDetailFeature.Errors

extension GaugeDetailFeature {
    public enum Errors: Error, LocalizedError {
        case invalidGaugeSourceURL

        public var errorDescription: String? {
            switch self {
            case .invalidGaugeSourceURL:
                "Invalid gauge source URL"
            }
        }
    }
}

class AppReviewManager {
    static func promptForReview() {
        #if os(macOS)
        SKStoreReviewController.requestReview()
        #endif
    }
}
