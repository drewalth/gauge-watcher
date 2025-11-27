//
//  GaugeSearchFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import ComposableArchitecture
import CoreLocation
import Foundation
import GaugeSources
import Loadable
import MapKit
import os
import SQLiteData
import SwiftUI

// MARK: - GaugeSearchFeature

@Reducer
struct GaugeSearchFeature {

    private let logger = Logger(category: "GaugeSearchFeature")

    @ObservableState
    struct State {
        var results: Loadable<[GaugeRef]> = .initial
        var queryOptions = GaugeQueryOptions()
        var initialized: Loadable<Bool> = .initial
        @Shared(.appStorage(LocalStorageKey.currentLocation.rawValue)) var currentLocation: CurrentLocation?
        var path = StackState<Path.State>()

        // Map position and region tracking for viewport-based queries
        var mapPosition: MapCameraPosition = .automatic
        var mapRegion: MKCoordinateRegion?

        static let defaultMapPosition: MapCameraPosition = .region(MKCoordinateRegion(
                                                                    center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
                                                                    span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 100)))
    }

    enum Action {
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
        case setMapPosition(MapCameraPosition)
    }

    @Dependency(\.gaugeService) var gaugeService: GaugeService
    @Dependency(\.locationService) var locationService: LocationService
    @Dependency(\.continuousClock) var clock

    @Reducer
    enum Path {
        case gaugeDetail(GaugeDetailFeature)
    }

    nonisolated enum CancelID {
        case query
        case mapRegionDebounce
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .goToGaugeDetail(let gaugeID):
                state.path.append(.gaugeDetail(GaugeDetailFeature.State(gaugeID)))
                return .none
            case .path(let action):
                print(action)
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
                state.$currentLocation.withLock { $0 = newValue }
                return .none
            case .setMapPosition(let position):
                state.mapPosition = position
                return .none
            case .mapRegionChanged(let region):
                // Don't update state immediately - only store when debounce fires
                // This prevents excessive state updates during pan/zoom
                return .run { send in
                    // Small debounce to handle rapid consecutive .onEnd events
                    try await clock.sleep(for: .milliseconds(200))
                    await send(.mapRegionChangeDebounced(region))
                }
                .cancellable(id: CancelID.mapRegionDebounce, cancelInFlight: true)
            case .mapRegionChangeDebounced(let region):
                // Only update state after user has stopped moving the map
                state.mapRegion = region

                let span = region.span
                let center = region.center

                // Check zoom level - only show gauges when zoomed in enough
                // latitudeDelta represents the visible height in degrees
                // ~5.0 degrees = ~350 miles (viewing entire large state)
                // ~1.0 degree = ~70 miles (viewing metro area)
                // ~0.5 degrees = ~35 miles (good detail level)
                let maxSpanForGauges = 3.5 // About 250 miles - reasonable for viewing gauges

                if span.latitudeDelta > maxSpanForGauges {
                    // Too zoomed out - clear results and show message via state
                    logger.info("Map too zoomed out (span: \(span.latitudeDelta)°) - clearing gauges")
                    state.results = .loaded([])
                    return .none
                }

                // Calculate bounding box from map region
                let boundingBox = BoundingBox(
                    minLatitude: center.latitude - span.latitudeDelta / 2,
                    maxLatitude: center.latitude + span.latitudeDelta / 2,
                    minLongitude: center.longitude - span.longitudeDelta / 2,
                    maxLongitude: center.longitude + span.longitudeDelta / 2)

                // Update query options to use bounding box instead of state/country
                var newOptions = state.queryOptions
                newOptions.boundingBox = boundingBox
                // Clear state/country filters when using bounding box
                newOptions.state = nil
                newOptions.country = nil

                state.queryOptions = newOptions
                return .send(.query)
            case .initialize:
                state.initialized = .loading
                // Set initial map position
                state.mapPosition = State.defaultMapPosition
                return .run { [locationService, logger] send in
                    // Subscribe to location service stream (receives initial state immediately)
                    for await delegateAction in await locationService.delegate() {
                        switch delegateAction {
                        case .initialState(let authStatus, let servicesEnabled):
                            // Handle initial state
                            guard servicesEnabled else {
                                logger.warning("Location services disabled - loading default gauges")
                                await send(.setQueryOptions(.init()))
                                await send(.query)
                                await send(.setInitialized(.loaded(true)))
                                return
                            }

                            switch authStatus {
                            case .notDetermined:
                                // Request authorization and wait for callback
                                logger.info("Requesting location authorization")
                                await locationService.requestWhenInUseAuthorization()
                            // Continue listening for authorization response

                            case .authorizedAlways, .authorizedWhenInUse:
                                // Already authorized - request location immediately
                                logger.info("Already authorized - fetching location")
                                await locationService.requestLocation()
                            // Continue listening for location update

                            case .denied, .restricted:
                                // User denied or restricted - load default gauges
                                logger.warning("Location denied/restricted - loading default gauges")
                                await send(.setQueryOptions(.init()))
                                await send(.query)
                                await send(.setInitialized(.loaded(true)))
                                return

                            @unknown default:
                                logger.warning("Unknown authorization status - loading default gauges")
                                await send(.setQueryOptions(.init()))
                                await send(.query)
                                await send(.setInitialized(.loaded(true)))
                                return
                            }

                        case .didChangeAuthorization(let newStatus):
                            switch newStatus {
                            case .authorizedAlways, .authorizedWhenInUse:
                                logger.info("Authorization granted - fetching location")
                                await locationService.requestLocation()
                            // Continue listening for location update

                            case .denied, .restricted:
                                logger.warning("Authorization denied - loading default gauges")
                                await send(.setQueryOptions(.init()))
                                await send(.query)
                                await send(.setInitialized(.loaded(true)))
                                return

                            case .notDetermined:
                                break

                            @unknown default:
                                break
                            }

                        case .didUpdateLocations(let locations):
                            do {
                                try await handleLocationUpdate(locations: locations, send: send, logger: logger)
                                return
                            } catch {
                                logger.error("Failed to handle location: \(error.localizedDescription)")
                                await send(.setInitialized(.error(error)))
                                return
                            }

                        case .didFailWithError(let error):
                            logger.error("Location error: \(error.localizedDescription) - loading default gauges")
                            await send(.setQueryOptions(.init()))
                            await send(.query)
                            await send(.setInitialized(.loaded(true)))
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
                state.results = .loading
                return .run { [state] send in
                    do {
                        let results = try await gaugeService.loadGauges(state.queryOptions).map { $0.ref }
                        await send(.setResults(.loaded(results)))
                    } catch {
                        await send(.setResults(.error(error)))
                    }
                }.cancellable(id: CancelID.query, cancelInFlight: true)
            case .setResults(let results):
                state.results = results
                return .none
            }
        }.forEach(\.path, action: \.path)
    }

    enum Mode {
        case map, list
    }
}

// MARK: - Helper Functions

private func handleLocationUpdate(
    locations: [CLLocation],
    send: Send<GaugeSearchFeature.Action>,
    logger: Logger)
async throws {
    logger.info("Processing location update with \(locations.count) locations")

    guard let location = locations.last else {
        throw GaugeSearchFeatureError.couldNotDetermineLocation
    }

    let currentLocation = CurrentLocation(
        latitude: location.coordinate.latitude,
        longitude: location.coordinate.longitude)

    await send(.setCurrentLocation(currentLocation))

    // Fly camera to user's location with smooth animation
    // Using .camera for a nice "fly to" effect with altitude
    //
    // this doesnt seem to work as expected.
    let cameraPosition = MapCameraPosition.camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(
                latitude: currentLocation.latitude,
                longitude: currentLocation.longitude),
            distance: 150_000, // ~93 miles altitude - good overview distance
            heading: 0,
            pitch: 0))
    await send(.setMapPosition(cameraPosition))

    // Using CLGeocoder - deprecated in iOS 26 but haven't gotten MapKit replacement working yet
    let geocoder = CLGeocoder()
    guard let placemark = try await geocoder.reverseGeocodeLocation(currentLocation.loc).first else {
        throw GaugeSearchFeatureError.couldNotGetMapItemFromGeocoding
    }

    guard let stateArea = placemark.administrativeArea else {
        throw GaugeSearchFeatureError.couldNotGetRegionName
    }

    guard let currentState = StatesProvinces.state(from: stateArea) else {
        throw GaugeSearchFeatureError.couldNotGetCurrentState
    }

    logger.info("Successfully determined state: \(currentState.abbreviation)")

    // Determine country and source based on the state/province
    let (country, source): (String, GaugeSource) = {
        if StatesProvinces.CanadianProvince(rawValue: currentState.abbreviation) != nil {
            return ("CA", .environmentCanada)
        } else if StatesProvinces.USState(rawValue: currentState.abbreviation) != nil {
            return ("US", .usgs)
        } else if StatesProvinces.NewZealandRegion(rawValue: currentState.abbreviation) != nil {
            return ("NZ", .lawa)
        } else {
            // Default to US/USGS if we can't determine
            logger.warning("Could not determine country for state: \(currentState.abbreviation), defaulting to US/USGS")
            return ("US", .usgs)
        }
    }()

    logger.info("Determined country: \(country), source: \(source.rawValue)")
    await send(.setQueryOptions(.init(country: country, state: currentState.abbreviation, source: source)))
    await send(.query)
    await send(.setInitialized(.loaded(true)))
}

// MARK: - CurrentLocation

nonisolated struct CurrentLocation: Equatable, Sendable, Codable {
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    var latitude: Double
    var longitude: Double

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
    }

    var loc: CLLocation {
        .init(latitude: latitude, longitude: longitude)
    }
}

// MARK: - GaugeSearchFeatureError

// state.currentLocation = .init(
//                        latitude: Double(location.coordinate.latitude),
//                        longitude: Double(location.coordinate.longitude))

enum GaugeSearchFeatureError: Error {
    case couldNotDetermineLocation
    case couldNotGetMapItemFromGeocoding
    case couldNotGetRegionName
    case couldNotGetCurrentState
}
