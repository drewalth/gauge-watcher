//
//  OnboardingReducer.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/19/25.
//

import CoreLocation
import SharedFeatures

// MARK: - OnboardingReducer

@Reducer
struct OnboardingReducer: Sendable {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var authorizationStatus: CLAuthorizationStatus = .notDetermined
        var locationPermissionRequested = false
        var isRequestingPermission = false
    }

    // MARK: - Action

    enum Action {
        case task
        case requestLocationPermission
        case locationDelegateAction(LocationManagerDelegateAction)
        case completeOnboarding
    }

    // MARK: - Dependencies

    @Dependency(\.locationService) var locationService

    // MARK: - Body

    var body: some Reducer<State, Action> {
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
}
