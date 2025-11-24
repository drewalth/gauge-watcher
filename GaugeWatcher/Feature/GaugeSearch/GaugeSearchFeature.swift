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
        var mode: Mode = .list
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

    @Dependency(\.databaseService) var databaseService: DatabaseService
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
                locationService.requestWhenInUseAuthorization()
                return .run { send in
                    for await delegateAction in await locationService.delegate() {
                        switch delegateAction {
                        case .didChangeAuthorization(let status):
                            switch status {
                            case .authorizedAlways, .authorizedWhenInUse:
                                logger.info("Starting location updates")
                                await locationService.startUpdatingLocation()
                            default: break
                            }
                        case .didUpdateLocations(let locations):
                            do {
                                // handle location updates with other effects
                                logger.info("did update locations \(locations.count)")
                                print(locations)
                                guard let location = locations.last else {
                                    throw GaugeSearchFeatureError.couldNotDetermineLocation
                                }

                                let currentLocation = CurrentLocation(
                                    latitude: location.coordinate.latitude,
                                    longitude: location.coordinate.longitude)

                                await send(.setCurrentLocation(currentLocation))

                                // Using CLGeocoder - deprecated in iOS 26 but havent gotten MapKit replacement working yet
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

                                logger.info("got current state")

                                await locationService.stopUpdatingLocation()

                                // TODO: get country based on current state abbreviation
                                await send(.setQueryOptions(.init(state: currentState.abbreviation)))
                                await send(.query)
                            } catch {
                                print(error)
                                await send(.setInitialized(.error(error)))
                            }

                        case .didFailWithError(let error):
                            logger.error("\(error.localizedDescription)")
                            await send(.setInitialized(.loaded(true)))
                        case .didDetermineState(let state, let region):
                            logger.info("did determine state")
                            print(state)
                            print(region)
                        case .didStartMonitoringFor:
                            logger.info("did start monitoring for ")
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
                        let results = try await databaseService.loadGauges(state.queryOptions).map { $0.ref }
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
