//
//  LocationServiceProtocol.swift
//  SharedFeatures
//
//  Platform-agnostic location service protocol.
//  Implementations are provided by each app target.
//

import ComposableArchitecture
import CoreLocation
import Foundation

// MARK: - LocationManagerDelegateAction

/// Actions emitted by the location service delegate
public enum LocationManagerDelegateAction: @unchecked Sendable {
    case didUpdateLocations([CLLocation])
    case didFailWithError(Swift.Error)
    case didChangeAuthorization(CLAuthorizationStatus)
    case initialState(authorizationStatus: CLAuthorizationStatus, servicesEnabled: Bool)
    case didDetermineState(CLRegionState, CLRegion)
    case didStartMonitoringFor(CLRegion)
}

// MARK: - LocationServiceProtocol

/// Platform-agnostic protocol for location services.
/// Each platform provides its own implementation.
@MainActor
public protocol LocationServiceProtocol: AnyObject, Sendable {
    /// Current authorization status
    var currentAuthorizationStatus: CLAuthorizationStatus { get }

    /// Current location (updated when locations are received)
    var currentLocation: CLLocation? { get }

    /// Provides a stream of location manager events, including initial state
    nonisolated func delegate() async -> AsyncStream<LocationManagerDelegateAction>

    /// Request when-in-use authorization
    nonisolated func requestWhenInUseAuthorization() async

    /// Request a single location update
    nonisolated func requestLocation() async

    /// Start continuous location updates
    nonisolated func startUpdatingLocation() async

    /// Stop location updates
    nonisolated func stopUpdatingLocation() async
}

// MARK: - LocationServiceKey

/// The location service dependency key
public struct LocationServiceKey: TestDependencyKey {
    public static var testValue: any LocationServiceProtocol {
        fatalError("LocationService must be provided for tests")
    }
}

extension DependencyValues {
    public var locationService: any LocationServiceProtocol {
        get { self[LocationServiceKey.self] }
        set { self[LocationServiceKey.self] = newValue }
    }
}
