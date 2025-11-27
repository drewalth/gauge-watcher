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
import os
import SQLiteData

// MARK: - GaugeSearchFeature

@Reducer
struct GaugeSearchFeature {

    private let logger = Logger(category: "GaugeSearchFeature")

    @ObservableState
    struct State {
        var results: Loadable<[GaugeRef]> = .initial
        var queryOptions = GaugeQueryOptions()
        var mode: Mode = .map
        var initialized: Loadable<Bool> = .initial
        @Shared(.appStorage(LocalStorageKey.currentLocation.rawValue)) var currentLocation: CurrentLocation?
        var path = StackState<Path.State>()
    }

    enum Action {
        case query
        case setQueryOptions(GaugeQueryOptions)
        case setResults(Loadable<[GaugeRef]>)
        case toggleMode
        case initialize
        case setInitialized(Loadable<Bool>)
        case setCurrentLocation(CurrentLocation?)
        case setSearchText(String)
        case path(StackActionOf<Path>)
        case goToGaugeDetail(Int)
    }

    @Dependency(\.gaugeService) var gaugeService: GaugeService
    @Dependency(\.locationService) var locationService: LocationService

    @Reducer
    enum Path {
        case gaugeDetail(GaugeDetailFeature)
    }

    nonisolated enum CancelID {
        case query
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
            case .initialize:
                state.initialized = .loading
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
            case .toggleMode:
                if state.mode == .list {
                    state.mode = .map
                } else {
                    state.mode = .list
                }
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
