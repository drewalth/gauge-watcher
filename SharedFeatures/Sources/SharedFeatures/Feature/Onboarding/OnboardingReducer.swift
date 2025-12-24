//
//  OnboardingReducer.swift
//  SharedFeatures
//
//  Reducer for handling onboarding flow and location permission requests.
//

import ComposableArchitecture
import CoreLocation

// MARK: - OnboardingReducer

@Reducer
public struct OnboardingReducer: Sendable {

    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    // MARK: - State

    @ObservableState
    public struct State: Equatable {

        // MARK: Lifecycle

        public init(
            authorizationStatus: CLAuthorizationStatus = .notDetermined,
            locationPermissionRequested: Bool = false,
            isRequestingPermission: Bool = false)
        {
            self.authorizationStatus = authorizationStatus
            self.locationPermissionRequested = locationPermissionRequested
            self.isRequestingPermission = isRequestingPermission
        }

        // MARK: Public

        public var authorizationStatus: CLAuthorizationStatus = .notDetermined
        public var locationPermissionRequested = false
        public var isRequestingPermission = false
    }

    // MARK: - Action

    public enum Action: Sendable {
        case task
        case requestLocationPermission
        case locationDelegateAction(LocationManagerDelegateAction)
        case completeOnboarding
    }

    // MARK: - Body

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    for await delegateAction in await locationService.delegate() {
                        await send(.locationDelegateAction(delegateAction))
                    }
                }

            case .requestLocationPermission:
                state.isRequestingPermission = true
                state.locationPermissionRequested = true
                return .run { _ in
                    await locationService.requestWhenInUseAuthorization()
                }

            case .locationDelegateAction(let delegateAction):
                switch delegateAction {
                case .initialState(let authorizationStatus, _):
                    state.authorizationStatus = authorizationStatus
                    state.isRequestingPermission = false
                case .didChangeAuthorization(let status):
                    state.authorizationStatus = status
                    state.isRequestingPermission = false
                default:
                    break
                }
                return .none

            case .completeOnboarding:
                return .none
            }
        }
    }

    // MARK: Private

    @Dependency(\.locationService) private var locationService

}

