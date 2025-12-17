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

/// Manual filter options for filtered search mode
public struct FilterOptions: Equatable, Sendable {

  // MARK: Lifecycle

  public init(
    country: String? = nil,
    state: String? = nil,
    source: GaugeSource? = nil,
    searchText: String = "")
  {
    self.country = country
    self.state = state
    self.source = source
    self.searchText = searchText
  }

  // MARK: Public

  public var country: String?
  public var state: String?
  public var source: GaugeSource?
  public var searchText: String = ""

  /// Returns true if any filter is actively set
  public var hasActiveFilters: Bool {
    country != nil || state != nil || source != nil || !searchText.isEmpty
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
      searchMode: SearchMode = .viewport,
      filterOptions: FilterOptions = FilterOptions(),
      shouldZoomToResults: Bool = false)
    {
      self.results = results
      self.queryOptions = queryOptions
      self.initialized = initialized
      self.path = path
      self.mapRegion = mapRegion
      self.shouldRecenterMap = shouldRecenterMap
      self.searchMode = searchMode
      self.filterOptions = filterOptions
      self.shouldZoomToResults = shouldZoomToResults
    }

    // MARK: Public

    public var results: Loadable<[GaugeRef]> = .initial
    public var queryOptions = GaugeQueryOptions()
    public var initialized: Loadable<Bool> = .initial
    @Shared(.appStorage(LocalStorageKey.currentLocation.rawValue)) public var currentLocation: CurrentLocation?
    public var path = StackState<Path.State>()

    // Map region tracking for viewport-based queries
    public var mapRegion: MKCoordinateRegion?

    // Flag to trigger recenter animation in MKMapView
    public var shouldRecenterMap = false

    // Search mode determines query behavior
    public var searchMode: SearchMode = .viewport

    // Manual filter options (used when searchMode == .filtered)
    public var filterOptions = FilterOptions()

    // Flag to trigger map zoom to fit results after filter query
    public var shouldZoomToResults = false

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

    // Search mode actions
    case setSearchMode(SearchMode)
    case updateFilterOptions(FilterOptions)
    case applyFilters
    case clearFilters
    case zoomToResultsCompleted
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
        state.$currentLocation.withLock { $0 = newValue }
        // Auto-recenter map when we get location for the first time
        if isFirstLocation {
          state.shouldRecenterMap = true
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
        // Only trigger viewport queries when in viewport mode
        guard state.searchMode == .viewport else { return .none }

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
        // Double-check we're still in viewport mode (could have changed during debounce)
        guard state.searchMode == .viewport else { return .none }

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
        // Clear state/country filters when using bounding box
        newOptions.state = nil
        newOptions.country = nil

        state.queryOptions = newOptions
        return .send(.query)

      // MARK: - Search Mode Actions

      case .setSearchMode(let mode):
        let previousMode = state.searchMode
        state.searchMode = mode

        // When switching to viewport mode, trigger a query based on current map region
        if mode == .viewport, previousMode == .filtered, let region = state.mapRegion {
          return .send(.mapRegionChangeDebounced(region))
        }

        // When switching to filtered mode, clear results until user applies filters
        if mode == .filtered, previousMode == .viewport {
          // Keep existing results visible until new filters are applied
          return .none
        }

        return .none

      case .updateFilterOptions(let options):
        state.filterOptions = options
        return .none

      case .applyFilters:
        // Build query options from filter options
        var queryOptions = GaugeQueryOptions()
        queryOptions.country = state.filterOptions.country
        queryOptions.state = state.filterOptions.state
        queryOptions.source = state.filterOptions.source
        if !state.filterOptions.searchText.isEmpty {
          queryOptions.name = state.filterOptions.searchText.lowercased()
        }
        // No bounding box for filtered queries
        queryOptions.boundingBox = nil

        state.queryOptions = queryOptions
        state.shouldZoomToResults = true
        return .send(.query)

      case .clearFilters:
        state.filterOptions = FilterOptions()
        state.results = .loaded([])
        return .none

      case .zoomToResultsCompleted:
        state.shouldZoomToResults = false
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
                await locationService.requestLocation()

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
                await locationService.requestLocation()

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
        state.results = .loading
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
      }
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


