//
//  App.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//

import AppTelemetry
import ComposableArchitecture
import SharedFeatures
import SwiftUI
import UIComponents

// MARK: - AppView

struct AppView: View {

    // MARK: Internal

    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            content()
        }
        .trackView("AppView")
        .task {
            store.send(.initialize)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(
                store: onboardingStore,
                onComplete: {
                    hasCompletedOnboarding = true
                    showOnboarding = false
                })
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
    }

    // MARK: Private

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    private var onboardingStore: StoreOf<OnboardingReducer> {
        Store(initialState: OnboardingReducer.State()) {
            OnboardingReducer()
        }
    }

    @ViewBuilder
    private func content() -> some View {
        switch store.initialized {
        case .initial, .reloading, .loading:
            ContinuousSpinner()
        case .error:
            UtilityBlockView(kind: .error("Something went wrong"))
        case .loaded(let isInitialized):
            if isInitialized {
                if let gaugeSearchStore = store.scope(state: \.gaugeSearch, action: \.gaugeSearch),
                   let favoritesStore = store.scope(state: \.favorites, action: \.favorites)
                {
                    GaugeSearch(
                        store: gaugeSearchStore,
                        gaugeBotStore: store.scope(state: \.gaugeBot, action: \.gaugeBot),
                        favoritesStore: favoritesStore
                    )
                } else {
                    ContinuousSpinner()
                }
            } else {
                UtilityBlockView(kind: .error("Something went wrong"))
            }
        }
    }
}
