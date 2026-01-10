//
//  GaugeSearchFeature.swift
//  SharedFeatures
//

import AppDatabase
import ComposableArchitecture
import CoreLocation
import Foundation
import GaugeService
import GaugeSources
import Loadable
import MapKit
import os

// MARK: - SearchMode

/// Determines how gauge queries are triggered
public enum SearchMode: Equatable, Sendable {
    /// Queries based on visible map area - panning triggers new queries
    case viewport
    /// Queries based on manual filters - map panning does not trigger queries
    case filtered
}

// MARK: - FilterOptions

/// Manual filter options for filtered search mode.
/// Note: Name-based searching is handled locally via the search bar in GaugeListInspector,
/// not as part of backend filter queries.
public struct FilterOptions: Equatable, Sendable {

    // MARK: Lifecycle

    public init(
        country: String? = nil,
        state: String? = nil,
        source: GaugeSource? = nil) {
        self.country = country
        self.state = state
        self.source = source
    }

    // MARK: Public

    public var country: String?
    public var state: String?
    public var source: GaugeSource?

    /// Returns true if any filter is actively set
    public var hasActiveFilters: Bool {
        country != nil || state != nil || source != nil
    }
}

// MARK: - GaugeSearchFeature

@Reducer
public struct GaugeSearchFeature: Sendable {

    // MARK: Lifecycle

    // MARK: - Initializer

    public init() { }

    // MARK: Public

    // MARK: - State

    @ObservableState
    public struct State {

        // MARK: Lifecycle

        public init(
            results: Loadable<[GaugeRef]> = .initial,
            queryOptions: GaugeQueryOptions = GaugeQueryOptions(),
            initialized: Loadable<Bool> = .initial,
            path: StackState<Path.State> = .init(),
            mapRegion: MKCoordinateRegion? = nil,
            shouldRecenterMap: Bool = false,
            filterOptions: FilterOptions = FilterOptions(),
            shouldZoomToResults: Bool = false,
            shouldFitAllPins: Bool = false,
            shouldCenterOnSelection: Bool = false,
            inspectorDetail: GaugeDetailFeature.State? = nil) {
            self.results = results
            self.queryOptions = queryOptions
            self.initialized = initialized
            self.path = path
            self.mapRegion = mapRegion
            self.shouldRecenterMap = shouldRecenterMap
            self.filterOptions = filterOptions
            self.shouldZoomToResults = shouldZoomToResults
            self.shouldFitAllPins = shouldFitAllPins
            self.shouldCenterOnSelection = shouldCenterOnSelection
            self.inspectorDetail = inspectorDetail
        }

        // MARK: Public

        public var results: Loadable<[GaugeRef]> = .initial
        public var queryOptions = GaugeQueryOptions()
        public var initialized: Loadable<Bool> = .initial
        public var currentLocation: CurrentLocation?
        public var path = StackState<Path.State>()

        // Map region tracking for viewport-based queries
        public var mapRegion: MKCoordinateRegion?

        // Flag to trigger recenter animation in MKMapView
        public var shouldRecenterMap = false

        // Manual filter options for filtered search mode
        public var filterOptions = FilterOptions()

        // Flag to trigger map zoom to fit results after filter query
        public var shouldZoomToResults = false

        // Flag to trigger map zoom to fit all pins
        public var shouldFitAllPins = false

        // Flag to trigger map center on selected gauge
        public var shouldCenterOnSelection = false

        // Inspector-based detail (macOS) - alternative to path-based navigation (iOS)
        public var inspectorDetail: GaugeDetailFeature.State?

        // Local search text for filtering displayed results (client-side, not backend query)
        // `localSearchText` updates immediately (for TextField binding)
        // `appliedSearchText` updates after debounce (for filtering)
        public var localSearchText = ""
        public var appliedSearchText = ""

        /// Search mode derived from filter state - filtered when filters are active, viewport otherwise
        public var searchMode: SearchMode {
            filterOptions.hasActiveFilters ? .filtered : .viewport
        }

        /// Whether the inspector should be shown (computed from inspectorDetail)
        public var isInspectorPresented: Bool {
            inspectorDetail != nil
        }

        /// Results filtered by applied search text. Use this for display instead of raw results.
        /// Uses `appliedSearchText` (debounced) to avoid excessive re-renders.
        public var filteredResults: [GaugeRef] {
            guard let gauges = results.unwrap(), !appliedSearchText.isEmpty else {
                return results.unwrap() ?? []
            }
            return gauges.filter { gauge in
                gauge.name.localizedStandardContains(appliedSearchText)
                    || gauge.state.localizedStandardContains(appliedSearchText)
                    || gauge.zone.localizedStandardContains(appliedSearchText)
            }
        }

    }

    // MARK: - Action

    public enum Action {
        case query
        case setQueryOptions(GaugeQueryOptions)
        case setResults(Loadable<[GaugeRef]>)
        case initialize
        case setInitialized(Loadable<Bool>)
        case setCurrentLocation(CurrentLocation?)
        case setSearchText(String)
        case path(StackActionOf<Path>)
        case goToGaugeDetail(Int)

        // Map viewport actions
        case mapRegionChanged(MKCoordinateRegion)
        case mapRegionChangeDebounced(MKCoordinateRegion)
        case recenterOnUserLocation
        case recenterCompleted

        // Filter actions
        case updateFilterOptions(FilterOptions)
        case applyFilters
        case clearFilters
        case zoomToResultsCompleted

        // Map control actions
        case fitAllPins
        case fitAllPinsCompleted
        case centerOnSelectedGauge
        case centerOnSelectionCompleted

        // Inspector-based detail (macOS)
        case selectGaugeForInspector(Int)
        case closeInspector
        case inspectorDetail(GaugeDetailFeature.Action)

        // Local search (client-side filtering)
        case setLocalSearchText(String)
        case applyLocalSearchText(String)
    }

    // MARK: - Path

    @Reducer
    public enum Path {
        case gaugeDetail(GaugeDetailFeature)
    }

    // MARK: - CancelID

    nonisolated public enum CancelID: Sendable {
        case query
        case mapRegionDebounce
        case localSearchDebounce
    }

    // MARK: - Display Mode

    public enum Mode {
        case map, list
    }

    // MARK: - Body

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .goToGaugeDetail(let gaugeID):
                state.path.append(.gaugeDetail(GaugeDetailFeature.State(gaugeID)))
                return .none

            case .path:
                return .none

            // MARK: - Inspector Actions (macOS)

            case .selectGaugeForInspector(let gaugeID):
                // If same gauge is already selected, do nothing
                if state.inspectorDetail?.gaugeID == gaugeID {
                    return .none
                }
                // Create new state and trigger load
                state.inspectorDetail = GaugeDetailFeature.State(gaugeID)
                return .send(.inspectorDetail(.load))

            case .closeInspector:
                state.inspectorDetail = nil
                return .none

            case .inspectorDetail:
                // Handled by child reducer
                return .none

            case .setSearchText(let newValue):
                var opt = state.queryOptions
                if !newValue.isEmpty {
                    opt.name = newValue.lowercased()
                } else {
                    opt.name = nil
                }
                state.queryOptions = opt
                return .send(.query)

            case .setCurrentLocation(let newValue):
                // Check if this is the first location update (previous was nil)
                let isFirstLocation = state.currentLocation == nil && newValue != nil
                state.currentLocation = newValue
                // Auto-recenter map and trigger query when we get location for the first time
                if isFirstLocation, let location = newValue {
                    state.shouldRecenterMap = true

                    // Create a bounding box around the user's location (~100km radius)
                    // and trigger a query immediately instead of waiting for map region change
                    let latDelta = 1.0 // ~111km
                    let lonDelta = 1.0 // ~85-111km depending on latitude
                    let boundingBox = BoundingBox(
                        minLatitude: location.latitude - latDelta,
                        maxLatitude: location.latitude + latDelta,
                        minLongitude: location.longitude - lonDelta,
                        maxLongitude: location.longitude + lonDelta)

                    var newOptions = GaugeQueryOptions()
                    newOptions.boundingBox = boundingBox
                    state.queryOptions = newOptions

                    // Note: Don't set mapRegion here synchronously - it causes reentrant layout issues
                    // with NSHostingView/MKMapView. The view will handle recentering via shouldRecenterMap,
                    // and mapRegionChanged will update mapRegion through the normal debounced flow.

                    return .send(.query)
                }
                return .none

            case .recenterOnUserLocation:
                guard state.currentLocation != nil else { return .none }
                state.shouldRecenterMap = true
                return .none

            case .recenterCompleted:
                state.shouldRecenterMap = false
                return .none

            case .mapRegionChanged(let region):
                // Only trigger viewport queries when no filters are active
                guard !state.filterOptions.hasActiveFilters else { return .none }

                // Don't update state immediately - only store when debounce fires
                // This prevents excessive state updates during pan/zoom
                return .run { send in
                    @Dependency(\.continuousClock) var clock
                    // Small debounce to handle rapid consecutive .onEnd events
                    try await clock.sleep(for: .milliseconds(200))
                    await send(.mapRegionChangeDebounced(region))
                }
                .cancellable(id: CancelID.mapRegionDebounce, cancelInFlight: true)

            case .mapRegionChangeDebounced(let region):
                // Double-check filters haven't been applied during debounce
                guard !state.filterOptions.hasActiveFilters else { return .none }

                // Only update state after user has stopped moving the map
                state.mapRegion = region

                let span = region.span
                let center = region.center

                // Calculate bounding box from map region
                let boundingBox = BoundingBox(
                    minLatitude: center.latitude - span.latitudeDelta / 2,
                    maxLatitude: center.latitude + span.latitudeDelta / 2,
                    minLongitude: center.longitude - span.longitudeDelta / 2,
                    maxLongitude: center.longitude + span.longitudeDelta / 2)

                // Update query options to use bounding box instead of state/country
                var newOptions = state.queryOptions
                newOptions.boundingBox = boundingBox
                // Clear all manual filters when using viewport-based bounding box queries
                newOptions.state = nil
                newOptions.country = nil
                newOptions.name = nil
                newOptions.source = nil

                state.queryOptions = newOptions
                return .send(.query)

            // MARK: - Filter Actions

            case .updateFilterOptions(let options):
                state.filterOptions = options
                return .none

            case .applyFilters:
                // Build query options from filter options
                var queryOptions = GaugeQueryOptions()
                queryOptions.country = state.filterOptions.country
                queryOptions.state = state.filterOptions.state
                queryOptions.source = state.filterOptions.source
                // No bounding box for filtered queries
                queryOptions.boundingBox = nil

                state.queryOptions = queryOptions
                state.shouldZoomToResults = true
                return .send(.query)

            case .clearFilters:
                state.filterOptions = FilterOptions()
                // Resume viewport-based queries if we have a map region
                if let region = state.mapRegion {
                    return .send(.mapRegionChangeDebounced(region))
                }
                state.results = .loaded([])
                return .none

            case .zoomToResultsCompleted:
                state.shouldZoomToResults = false
                return .none

            // MARK: - Map Control Actions

            case .fitAllPins:
                guard let results = state.results.unwrap(), !results.isEmpty else { return .none }
                state.shouldFitAllPins = true
                return .none

            case .fitAllPinsCompleted:
                state.shouldFitAllPins = false
                return .none

            case .centerOnSelectedGauge:
                guard state.inspectorDetail != nil else { return .none }
                state.shouldCenterOnSelection = true
                return .none

            case .centerOnSelectionCompleted:
                state.shouldCenterOnSelection = false
                return .none

            case .initialize:
                // Show the map immediately - don't block on location
                state.initialized = .loaded(true)

                // Start location acquisition in background - map will update when ready
                return .run { [logger] send in
                    @Dependency(\.locationService) var locationService

                    // Subscribe to location service stream (receives initial state immediately)
                    for await delegateAction in await locationService.delegate() {
                        switch delegateAction {
                        case .initialState(let authStatus, let servicesEnabled):
                            guard servicesEnabled else {
                                logger.warning("Location services disabled")
                                return
                            }

                            switch authStatus {
                            case .notDetermined:
                                logger.info("Requesting location authorization")
                                await locationService.requestWhenInUseAuthorization()

                            case .authorizedAlways, .authorizedWhenInUse:
                                logger.info("Already authorized - fetching location")
                                // Use startUpdatingLocation instead of requestLocation - more reliable on macOS
                                await locationService.startUpdatingLocation()

                            case .denied, .restricted:
                                logger.warning("Location denied/restricted")
                                return

                            @unknown default:
                                return
                            }

                        case .didChangeAuthorization(let newStatus):
                            switch newStatus {
                            case .authorizedAlways, .authorizedWhenInUse:
                                logger.info("Authorization granted - fetching location")
                                // Use startUpdatingLocation instead of requestLocation - more reliable on macOS
                                await locationService.startUpdatingLocation()

                            case .denied, .restricted:
                                logger.warning("Authorization denied")
                                return

                            case .notDetermined:
                                break

                            @unknown default:
                                break
                            }

                        case .didUpdateLocations(let locations):
                            guard let location = locations.last else { return }
                            // Stop location updates - we only need one location
                            await locationService.stopUpdatingLocation()
                            let currentLocation = CurrentLocation(
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude)
                            await send(.setCurrentLocation(currentLocation))
                            logger.info("Location acquired: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                            return

                        case .didFailWithError(let error):
                            logger.error("Location error: \(error.localizedDescription)")
                            return

                        case .didDetermineState, .didStartMonitoringFor:
                            break
                        }
                    }
                }

            case .setInitialized(let newValue):
                state.initialized = newValue
                return .none

            case .setQueryOptions(let newValue):
                state.queryOptions = newValue
                return .none

            case .query:
                if state.results.isLoaded() {
                    state.results = .reloading(state.results.unwrap() ?? [])
                } else if state.results.isInitial() || state.results.isError() {
                    state.results = .loading
                }
                return .run { [queryOptions = state.queryOptions] send in
                    do {
                        @Dependency(\.gaugeService) var gaugeService
                        let results = try await gaugeService.loadGauges(queryOptions).map { $0.ref }
                        await send(.setResults(.loaded(results)))
                    } catch {
                        await send(.setResults(.error(error)))
                    }
                }.cancellable(id: CancelID.query, cancelInFlight: true)

            case .setResults(let results):
                state.results = results
                return .none

            case .setLocalSearchText(let text):
                // Update text field immediately for responsive typing
                state.localSearchText = text

                // If clearing, apply immediately without debounce
                if text.isEmpty {
                    state.appliedSearchText = ""
                    return .cancel(id: CancelID.localSearchDebounce)
                }

                // Debounce the actual filtering to avoid excessive re-renders
                return .run { send in
                    @Dependency(\.continuousClock) var clock
                    try await clock.sleep(for: .milliseconds(300))
                    await send(.applyLocalSearchText(text))
                }
                .cancellable(id: CancelID.localSearchDebounce, cancelInFlight: true)

            case .applyLocalSearchText(let text):
                // Only apply if it still matches current input (user may have typed more)
                guard text == state.localSearchText else { return .none }
                state.appliedSearchText = text
                return .none
            }
        }
        .ifLet(\.inspectorDetail, action: \.inspectorDetail) {
            GaugeDetailFeature()
        }
        .forEach(\.path, action: \.path)
    }

    // MARK: Private

    private let logger = Logger(category: "GaugeSearchFeature")

}

// MARK: - CurrentLocation

public struct CurrentLocation: Equatable, Sendable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
    }

    public var loc: CLLocation {
        .init(latitude: latitude, longitude: longitude)
    }
}
