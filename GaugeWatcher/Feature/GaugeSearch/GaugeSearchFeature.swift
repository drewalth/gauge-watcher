//
//  GaugeSearchFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import ComposableArchitecture
import Loadable
import os
import SQLiteData
import Foundation
import CoreLocation
import GaugeSources

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
    }

    @Dependency(\.databaseService) var databaseService: DatabaseService
    @Dependency(\.locationService) var locationService: LocationService

    
    nonisolated enum CancelID {
        case query
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
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
                locationService.requestWhenInUseAuthorization()
                return .run { send in
                                    for await delegateAction in await locationService.delegate() {
                                        switch delegateAction {
                                        case .didChangeAuthorization(let status):
                                            // handle authorization changes with other effects
                                            logger.info("did change authorization status \(status.customDumpDescription)")
                                            await send(.setInitialized(.loaded(true)))
                                        case .didUpdateLocations(let locations):
                                            // handle location updates with other effects
                                            logger.info("did update locations \(locations.count)")
                                            print(locations)
                                            guard let location = locations.last else {
                                                logger.error("cound not determine location")
                                                return
                                            }
                                            let currentLocation = CurrentLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                                            
                                            await send(.setCurrentLocation(currentLocation))
                                            
                                            let geocoder = CLGeocoder()
                                            guard let placemark = try await geocoder.reverseGeocodeLocation(currentLocation.loc).first else {
                                                logger.error("could not get placemark")
                                                return
                                            }
                                            
                                            guard let stateArea = placemark.administrativeArea else {
                                                logger.error("could not get state area")
                                                return
                                            }
                                            
                                            guard let currentState = StatesProvinces.state(from: stateArea) else {
                                                logger.error("could not get current state")
                                                return
                                            }
                                            
                                            logger.info("got current state")
                                            print(currentState)
                                            
                                            // todo: get country based on current state abbreviation
                                            
                                            await send(.setQueryOptions(.init(state: currentState.abbreviation)))
                                            await send(.query)
                                            
                                        case .didFailWithError(let error):
                                            logger.error("\(error.localizedDescription)")
                                            await send(.setInitialized(.loaded(true)))
                                        case .didDetermineState(let state, let region):
                                            logger.info("did determine state")
                                            print(state)
                                            print(region)
                                        case .didStartMonitoringFor(_):
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
        }
    }
    
    enum Mode {
        case map, list
    }
}

nonisolated struct CurrentLocation: Equatable, Sendable, Codable {
     init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

     var latitude: Double
     var longitude: Double
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.latitude = try container.decode(Double.self, forKey: .latitude)
        self.longitude = try container.decode(Double.self, forKey: .longitude)
    }
    
    var loc: CLLocation {
        .init(latitude: self.latitude, longitude: self.longitude)
    }
}

/*
 state.currentLocation = .init(
                         latitude: Double(location.coordinate.latitude),
                         longitude: Double(location.coordinate.longitude))
 */
