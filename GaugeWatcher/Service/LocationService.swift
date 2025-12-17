//
//  LocationService.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import Combine
import ComposableArchitecture
import CoreLocation
import os
import SharedFeatures

// MARK: - LocationService

@MainActor
final class LocationService: NSObject, LocationServiceProtocol {

    // MARK: Public

    /// Current authorization status (safe to access, updated reactively)
    public private(set) var currentAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Current location (updated when locations are received)
    public private(set) var currentLocation: CLLocation?

    /// Provides a stream of location manager events, including initial state
    nonisolated public func delegate() async -> AsyncStream<SharedFeatures.LocationManagerDelegateAction> {
        // Safely access MainActor properties
        let initialAuth = await currentAuthorizationStatus
        let subject = await delegateSubject

        return AsyncStream { continuation in
            // Emit initial state immediately
            let servicesEnabled = CLLocationManager.locationServicesEnabled()
            continuation.yield(.initialState(
                                authorizationStatus: initialAuth,
                                servicesEnabled: servicesEnabled))

            // Subscribe to future updates
            let subscription = subject.sink { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in subscription.cancel() }
        }
    }

    // MARK: Internal

    let locationManager = CLLocationManager()
    let delegateSubject = PassthroughSubject<SharedFeatures.LocationManagerDelegateAction, Never>()

    func initialize() {
        locationManager.delegate = self

        // Initialize current state
        currentAuthorizationStatus = Self.getAuthorizationStatus(from: locationManager)
    }

    // MARK: Private

    private let logger = Logger(category: "LocationManager")

    private static func getAuthorizationStatus(from manager: CLLocationManager) -> CLAuthorizationStatus {
        #if os(macOS)
        if #available(macOS 11.0, *) {
            return manager.authorizationStatus
        } else if #available(macOS 10.12, *) {
            return manager.authorizationStatus
        } else {
            return .notDetermined
        }
        #else
        if #available(iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
            return manager.authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
        #endif
    }
}

// MARK: CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated public func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.currentLocation = locations.last
            self.delegateSubject.send(.didUpdateLocations(locations))
        }
    }

    nonisolated public func locationManager(_: CLLocationManager, didFailWithError error: Swift.Error) {
        Task { @MainActor in
            self.delegateSubject.send(.didFailWithError(error))
        }
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, *)
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = Self.getAuthorizationStatus(from: manager)
            self.currentAuthorizationStatus = status
            self.delegateSubject.send(.didChangeAuthorization(status))
        }
    }

    @available(iOS, introduced: 4.2, deprecated: 14.0)
    @available(tvOS, introduced: 9.0, deprecated: 14.0)
    @available(macOS, introduced: 10.7, deprecated: 11.0)
    nonisolated public func locationManager(_: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.currentAuthorizationStatus = status
            self.delegateSubject.send(.didChangeAuthorization(status))
        }
    }

    #if os(iOS) || os(macOS)
    @available(iOS 7.0, macOS 10.10, *)
    nonisolated public func locationManager(_: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        Task { @MainActor in
            self.delegateSubject.send(.didDetermineState(state, region))
        }
    }

    @available(iOS 5.0, macOS 10.8, *)
    nonisolated public func locationManager(_: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        Task { @MainActor in
            self.delegateSubject.send(.didStartMonitoringFor(region))
        }
    }
    #endif
}

// MARK: - Commands (not queries)

extension LocationService {

    nonisolated public func requestWhenInUseAuthorization() async {
        await logger.info("Requesting Location Services Authorization")
        await locationManager.requestWhenInUseAuthorization()
    }

    nonisolated public func requestLocation() async {
        await logger.info("Requesting single location update")
        #if os(iOS) || os(macOS)
        if #available(iOS 9.0, macOS 10.12, *) {
            await locationManager.requestLocation()
        } else {
            // Fallback for earlier versions
            await locationManager.startUpdatingLocation()
        }
        #endif
    }

    nonisolated public func startUpdatingLocation() async {
        await logger.info("Starting continuous location updates")
        #if os(iOS) || os(macOS)
        await locationManager.startUpdatingLocation()
        #endif
    }

    nonisolated public func stopUpdatingLocation() async {
        await logger.info("Stopping location updates")
        #if os(iOS) || os(macOS)
        await locationManager.stopUpdatingLocation()
        #endif
    }
}

// MARK: - LocationServiceKey + DependencyKey

extension LocationServiceKey: DependencyKey {
    @MainActor
    public static var liveValue: any LocationServiceProtocol = {
        let client = LocationService()
        client.initialize()
        return client
    }()
}
