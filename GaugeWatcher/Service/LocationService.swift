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

public enum LocationManagerDelegateAction {
  case didUpdateLocations([CLLocation])
    case didFailWithError(Swift.Error)
  case didChangeAuthorization(CLAuthorizationStatus)

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
  case didDetermineState(CLRegionState, CLRegion)
  #endif

  case didStartMonitoringFor(CLRegion)
}

class LocationService: NSObject {
    public func delegate() async -> AsyncStream<LocationManagerDelegateAction> {
        AsyncStream { continuation in
          let subscription = self.delegateSubject.sink { value in
            continuation.yield(value)
          }
          continuation.onTermination = { _ in subscription.cancel() }
        }
      }
    
    let locationManager = CLLocationManager()
     let delegateSubject = PassthroughSubject<LocationManagerDelegateAction, Never>()
    
    func initialize() {
       locationManager.delegate = self
     }
    
    private let logger = Logger(category: "LocationManager")
}

extension LocationService: CLLocationManagerDelegate {
  public func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    delegateSubject.send(.didUpdateLocations(locations))
  }

  public func locationManager(_: CLLocationManager, didFailWithError error: Swift.Error) {
    delegateSubject.send(.didFailWithError(error))
  }

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, *)
  public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status: CLAuthorizationStatus
    #if os(macOS)
    status = manager.authorizationStatus
    #else
    status = CLLocationManager.authorizationStatus()
    #endif
    delegateSubject.send(.didChangeAuthorization(status))
  }

  @available(iOS, introduced: 4.2, deprecated: 14.0)
  @available(tvOS, introduced: 9.0, deprecated: 14.0)
  @available(macOS, introduced: 10.7, deprecated: 11.0)
  public func locationManager(_: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    delegateSubject.send(.didChangeAuthorization(status))
  }

  #if os(iOS) || os(macOS)
  @available(iOS 7.0, macOS 10.10, *)
  public func locationManager(_: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
    delegateSubject.send(.didDetermineState(state, region))
  }

  @available(iOS 5.0, macOS 10.8, *)
  public func locationManager(_: CLLocationManager, didStartMonitoringFor region: CLRegion) {
    delegateSubject.send(.didStartMonitoringFor(region))
  }
  #endif
}

extension LocationService{

  public func requestWhenInUseAuthorization() {
    let authStatus = authorizationStatus()
    switch authStatus {
    case .notDetermined:
      logger.info("Requesting Location Services Authorization")
      locationManager.requestWhenInUseAuthorization()
    case .restricted, .denied:
      logger.warning("Location Services Denied")
    case .authorizedWhenInUse, .authorizedAlways:
      logger.info("Location Services Authorized")
      startUpdatingLocation()
    @unknown default:
      break
    }
  }

  public func requestLocation() {
    logger.info("Requesting Location")
    #if os(iOS) || os(macOS)
    if #available(iOS 9.0, macOS 10.12, *) {
      locationManager.requestLocation()
    } else {
      // Fallback for earlier versions if necessary
    }
    #endif
  }

  public func startUpdatingLocation() {
    logger.info("Starting Location Updates")
    #if os(iOS) || os(macOS)
    locationManager.startUpdatingLocation()
    #endif
  }

  public func stopUpdatingLocation() {
    logger.info("Stopping Location Updates")
    #if os(iOS) || os(macOS)
    locationManager.stopUpdatingLocation()
    #endif
  }

  public func authorizationStatus() -> CLAuthorizationStatus {
    logger.info("Getting Location Authorization Status")
    #if os(macOS)
    if #available(macOS 10.12, *) {
      return locationManager.authorizationStatus
    } else {
      return .notDetermined
    }
    #else
    return CLLocationManager.authorizationStatus()
    #endif
  }
}

extension LocationService: DependencyKey {
  public static var liveValue: LocationService = {
    let client = LocationService()
    client.initialize()
    return client
  }()
}

extension DependencyValues {
   var locationService: LocationService {
    get { self[LocationService.self] }
    set { self[LocationService.self] = newValue }
  }
}
