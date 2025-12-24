//
//  GaugeDetailFeature.swift
//  SharedFeatures
//

#if canImport(Cocoa)
import Cocoa
#endif
import AppTelemetry
import ComposableArchitecture
import Foundation
import GaugeDrivers
import GaugeService
import GaugeSources
import Loadable
import MapKit
import os
import StoreKit

#if DEBUG
private let debugLogger = Logger(subsystem: "com.gaugewatcher.debug", category: "GaugeDetailFeature")
#endif
private func debugLog(_ location: String, _ message: String, _ data: [String: Any], hypothesisId: String) {
    #if DEBUG
    // Log to Console.app via os.Logger (works in sandbox)
    let dataString = data.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    debugLogger.notice("[\(hypothesisId)] \(location): \(message) | \(dataString)")

    // Also try to write to sandbox-accessible caches directory
    if let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
        let logURL = cachesURL.appending(path: "gauge_debug.log")
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let logData: [String: Any] = [
            "location": location,
            "message": message,
            "data": data,
            "timestamp": timestamp,
            "sessionId": "debug-session",
            "hypothesisId": hypothesisId
        ]
        if
            let jsonData = try? JSONSerialization.data(withJSONObject: logData), let jsonString = String(
                data: jsonData,
                encoding: .utf8) {
            let line = jsonString + "\n"
            if FileManager.default.fileExists(atPath: logURL.path()) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(line.data(using: .utf8)!)
                    try? handle.close()
                }
            } else {
                try? line.write(to: logURL, atomically: true, encoding: .utf8)
            }
        }
    }
    #endif
}

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
        /// Tracks whether we've already synced this session to prevent infinite loops
        var hasSyncedThisSession = false

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
        case setHasSyncedThisSession(Bool)
    }

    // MARK: - CancelID

    nonisolated public enum CancelID: Sendable {
        case sync
        case loadReadings
        case load
    }

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
                        logger.error("\(prefixError(for: #function, error: error))")
                        AppTelemetry.captureEvent(prefixError(for: #function, error: error))
                    }
                }
            case .setAppReviewRequested(let newValue):
                state.$appReviewRequested.withLock { $0 = newValue }
                return .none
            case .setHasSyncedThisSession(let newValue):
                state.hasSyncedThisSession = newValue
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
                        logger.error("\(prefixError(for: #function, error: error))")
                        await send(.setForecast(.error(error)))

                        AppTelemetry.captureEvent(prefixError(for: #function, error: error))
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
                        logger.error("\(prefixError(for: #function, error: error))")
                        AppTelemetry.captureEvent(prefixError(for: #function, error: error))
                    }
                }

            case .toggleFavorite:
                guard state.gauge.unwrap() != nil else {
                    return .none
                }
                return .concatenate(
                    .run { [gaugeID = state.gaugeID] _ in
                        do {
                            @Dependency(\.gaugeService) var gaugeService
                            try await gaugeService.toggleFavorite(gaugeID)
                        } catch {
                            logger.error("\(prefixError(for: #function, error: error))")

                            AppTelemetry.captureEvent(prefixError(for: #function, error: error))
                        }
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
                let readingsDesc: String
                switch newValue {
                case .initial: readingsDesc = "initial"
                case .loading: readingsDesc = "loading"
                case .loaded(let arr): readingsDesc = "loaded(\(arr.count))"
                case .reloading(let arr): readingsDesc = "reloading(\(arr.count))"
                case .error(let err): readingsDesc = "error(\(err.localizedDescription))"
                }
                debugLog("GaugeDetailFeature.setReadings", "Setting readings state", ["newValue": readingsDesc], hypothesisId: "C")

                state.readings = newValue
                return .none

            case .loadReadings:
                let readingsStateDesc = state.readings.isLoaded() ? "loaded" : "notLoaded"
                debugLog(
                    "GaugeDetailFeature.loadReadings:entry",
                    "loadReadings action triggered",
                    ["gaugeID": state.gaugeID, "readingsState": readingsStateDesc, "hasSyncedThisSession": state.hasSyncedThisSession],
                    hypothesisId: "C")

                // If we already have readings, show them while reloading. Otherwise, show loading.
                if state.readings.isLoaded() {
                    state.readings = .reloading(state.readings.unwrap()!)
                } else {
                    state.readings = .loading
                }

                return .run { [gaugeID = state.gaugeID, hasSyncedThisSession = state.hasSyncedThisSession] send in
                    debugLog(
                        "GaugeDetailFeature.loadReadings:run",
                        "Effect started, fetching readings",
                        ["gaugeID": gaugeID, "hasSyncedThisSession": hasSyncedThisSession],
                        hypothesisId: "D")

                    do {
                        @Dependency(\.gaugeService) var gaugeService
                        let readings = try await gaugeService.loadGaugeReadings(.init(gaugeID: gaugeID)).map { $0.ref }

                        debugLog(
                            "GaugeDetailFeature.loadReadings:fetched",
                            "Readings fetched from service",
                            [
                                "gaugeID": gaugeID,
                                "readingsCount": readings.count,
                                "isEmpty": readings.isEmpty,
                                "hasSyncedThisSession": hasSyncedThisSession
                            ],
                            hypothesisId: "C")

                        // If readings are empty and we haven't synced this session, trigger a sync to fetch from API
                        if readings.isEmpty, !hasSyncedThisSession {
                            debugLog(
                                "GaugeDetailFeature.loadReadings:triggerSync",
                                "Empty readings detected, triggering sync",
                                ["gaugeID": gaugeID],
                                hypothesisId: "C")

                            await send(.sync)
                            return
                        }

                        let availableMetrics = getAvailableMetrics(for: readings)

                        let metricRawValues = availableMetrics.map { $0.rawValue }
                        debugLog(
                            "GaugeDetailFeature.loadReadings:metrics",
                            "Available metrics computed",
                            ["gaugeID": gaugeID, "metricsCount": availableMetrics.count, "metrics": metricRawValues],
                            hypothesisId: "E")

                        await send(.setAvailableMetrics(availableMetrics))
                        if let selectedMetric = availableMetrics.first {
                            debugLog(
                                "GaugeDetailFeature.loadReadings:selectedMetric",
                                "Selected first metric",
                                ["gaugeID": gaugeID, "selectedMetric": selectedMetric.rawValue],
                                hypothesisId: "E")

                            await send(.setSelectedMetric(selectedMetric))
                        } else {
                            debugLog(
                                "GaugeDetailFeature.loadReadings:noMetric",
                                "No available metrics to select",
                                ["gaugeID": gaugeID],
                                hypothesisId: "E")
                        }
                        await Task.yield()

                        debugLog(
                            "GaugeDetailFeature.loadReadings:complete",
                            "Sending setReadings with loaded data",
                            ["gaugeID": gaugeID, "readingsCount": readings.count],
                            hypothesisId: "C")

                        await send(.setReadings(.loaded(readings)))

                    } catch {
                        debugLog(
                            "GaugeDetailFeature.loadReadings:error",
                            "loadReadings failed with error",
                            ["gaugeID": gaugeID, "error": error.localizedDescription],
                            hypothesisId: "D")

                        await send(.setReadings(.error(error)))
                        AppTelemetry.captureEvent(prefixError(for: #function, error: error))
                    }
                }.cancellable(id: CancelID.loadReadings, cancelInFlight: true)

            case .sync:
                let hasGauge = state.gauge.unwrap() != nil
                debugLog(
                    "GaugeDetailFeature.sync:entry",
                    "Sync action triggered",
                    ["gaugeID": state.gaugeID, "hasGauge": hasGauge],
                    hypothesisId: "B")

                guard let gauge = state.gauge.unwrap() else {
                    debugLog(
                        "GaugeDetailFeature.sync:noGauge",
                        "Sync aborted - gauge not in state",
                        ["gaugeID": state.gaugeID],
                        hypothesisId: "B")

                    logger.warning("\(prefixError(for: #function, error: Errors.gaugeNotSetInState))")
                    return .none
                }

                state.gauge = .reloading(gauge)
                if state.readings.isLoaded() {
                    state.readings = .reloading(state.readings.unwrap()!)
                } else {
                    state.readings = .loading
                }
                return .run { [gaugeID = state.gaugeID] send in
                    debugLog("GaugeDetailFeature.sync:run", "Sync effect started", ["gaugeID": gaugeID], hypothesisId: "B")

                    do {
                        @Dependency(\.gaugeService) var gaugeService
                        // Sync with API
                        try await gaugeService.sync(gaugeID)

                        debugLog(
                            "GaugeDetailFeature.sync:synced",
                            "Sync API call completed - status returned from API should be saved",
                            ["gaugeID": gaugeID],
                            hypothesisId: "B")

                        // Reload gauge from database after sync
                        let updatedGauge = try await gaugeService.loadGauge(gaugeID).ref
                        await send(.setGauge(.loaded(updatedGauge)))
                        await send(.setHasSyncedThisSession(true))

                        debugLog(
                            "GaugeDetailFeature.sync:reloaded",
                            "Gauge reloaded after sync, calling loadReadings",
                            ["gaugeID": gaugeID, "hasSyncedThisSession": true, "statusAfterSync": updatedGauge.status.rawValue],
                            hypothesisId: "B")

                        // Now load readings
                        await send(.loadReadings)
                    } catch {
                        debugLog(
                            "GaugeDetailFeature.sync:error",
                            "Sync failed with error",
                            ["gaugeID": gaugeID, "error": error.localizedDescription],
                            hypothesisId: "B")

                        await send(.setGauge(.error(error)))
                        await send(.setReadings(.error(error)))

                        AppTelemetry.captureEvent(prefixError(for: #function, error: error))
                    }
                }.cancellable(id: CancelID.sync, cancelInFlight: false)

            case .setGauge(let newValue):
                let gaugeDesc: String
                switch newValue {
                case .initial: gaugeDesc = "initial"
                case .loading: gaugeDesc = "loading"
                case .loaded(let g): gaugeDesc = "loaded(\(g.name))"
                case .reloading(let g): gaugeDesc = "reloading(\(g.name))"
                case .error(let err): gaugeDesc = "error(\(err.localizedDescription))"
                }
                debugLog(
                    "GaugeDetailFeature.setGauge",
                    "Setting gauge state",
                    ["gaugeID": state.gaugeID, "newValue": gaugeDesc],
                    hypothesisId: "A")

                state.gauge = newValue
                return .none

            case .load:
                let gaugeStateDesc = state.gauge.isLoaded() ? "loaded" : (state.gauge.isInitial() ? "initial" : "other(\(state.gauge))")
                debugLog(
                    "GaugeDetailFeature.load:entry",
                    "Load action triggered",
                    ["gaugeID": state.gaugeID, "gaugeState": gaugeStateDesc],
                    hypothesisId: "A")

                if state.gauge.isLoaded() {
                    state.gauge = .reloading(state.gauge.unwrap()!)
                } else if state.gauge.isInitial() {
                    state.gauge = .loading
                }
                return .run { [gaugeID = state.gaugeID, logger] send in
                    debugLog("GaugeDetailFeature.load:run", "Effect started, fetching gauge", ["gaugeID": gaugeID], hypothesisId: "A")

                    do {
                        @Dependency(\.gaugeService) var gaugeService
                        let gauge = try await gaugeService.loadGauge(gaugeID).ref

                        debugLog(
                            "GaugeDetailFeature.load:gaugeLoaded",
                            "Gauge loaded from service",
                            [
                                "gaugeID": gaugeID,
                                "gaugeName": gauge.name,
                                "gaugeSource": gauge.source.rawValue,
                                "isStale": gauge.isStale(),
                                "status": gauge.status.rawValue
                            ],
                            hypothesisId: "B")

                        await send(.setGauge(.loaded(gauge)))

                        if gauge.source == .usgs {
                            await send(.setForecastAvailable(.loaded(true)))
                        }

                        if gauge.isStale() {
                            debugLog("GaugeDetailFeature.load:staleCheck", "Gauge IS stale, will sync", ["gaugeID": gaugeID], hypothesisId: "B")

                            logger.info("syncing gauge")
                            await send(.sync)
                        } else {
                            debugLog(
                                "GaugeDetailFeature.load:staleCheck",
                                "Gauge NOT stale, calling loadReadings directly",
                                ["gaugeID": gaugeID],
                                hypothesisId: "B")

                            // Only load readings if we're not syncing (sync will load them after)
                            await send(.loadReadings)
                        }

                    } catch {
                        debugLog(
                            "GaugeDetailFeature.load:error",
                            "Load gauge failed with error",
                            ["gaugeID": gaugeID, "error": error.localizedDescription],
                            hypothesisId: "A")

                        await send(.setGauge(.error(error)))

                        AppTelemetry.captureEvent(prefixError(for: #function, error: error))
                    }
                }.cancellable(id: CancelID.load, cancelInFlight: true)
            }
        }
    }

    // MARK: Internal

    @Dependency(\.continuousClock) var clock

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
        case gaugeNotSetInState

        public var errorDescription: String? {
            switch self {
            case .invalidGaugeSourceURL:
                "Invalid gauge source URL"
            case .gaugeNotSetInState:
                "Gauge not set in state"
            }
        }
    }
}

// MARK: - AppReviewManager

class AppReviewManager {
    static func promptForReview() {
        #if os(macOS)
        SKStoreReviewController.requestReview()
        #endif
    }
}

private func prefixError(for method: String, error: Error) -> String {
    "[GaugeDetailFeature] \(method): \(error.localizedDescription)"
}
