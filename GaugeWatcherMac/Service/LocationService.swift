//
//  LocationService.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
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
        currentAuthorizationStatus = locationManager.authorizationStatus
    }

    // MARK: Private

    private let logger = Logger(subsystem: "com.drewalth.GaugeWatcherMac", category: "LocationService")
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

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            self.currentAuthorizationStatus = status
            self.delegateSubject.send(.didChangeAuthorization(status))
        }
    }

    nonisolated public func locationManager(
        _: CLLocationManager,
        didDetermineState state: CLRegionState,
        for region: CLRegion) {
        Task { @MainActor in
            self.delegateSubject.send(.didDetermineState(state, region))
        }
    }

    nonisolated public func locationManager(_: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        Task { @MainActor in
            self.delegateSubject.send(.didStartMonitoringFor(region))
        }
    }
}

// MARK: - Commands

extension LocationService {

    nonisolated public func requestWhenInUseAuthorization() async {
        await MainActor.run {
            logger.info("Requesting Location Services Authorization")
            locationManager.requestWhenInUseAuthorization()
        }
    }

    nonisolated public func requestLocation() async {
        await MainActor.run {
            logger.info("Requesting single location update")
            locationManager.requestLocation()
        }
    }

    nonisolated public func startUpdatingLocation() async {
        await MainActor.run {
            logger.info("Starting continuous location updates")
            locationManager.startUpdatingLocation()
        }
    }

    nonisolated public func stopUpdatingLocation() async {
        await MainActor.run {
            logger.info("Stopping location updates")
            locationManager.stopUpdatingLocation()
        }
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
