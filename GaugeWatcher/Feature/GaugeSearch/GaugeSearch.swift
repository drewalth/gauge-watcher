//
//  GaugeSearch.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/22/25.
//

import AppTelemetry
import ComposableArchitecture
import Loadable
import SharedFeatures
import SwiftUI
import UIComponents

struct GaugeSearch: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeSearchFeature>
    @Bindable var gaugeBotStore: StoreOf<GaugeBotReducer>
    @Bindable var favoritesStore: StoreOf<FavoriteGaugesFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            mapContent()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("My Location", systemImage: "location") {
                            store.send(.recenterOnUserLocation)
                        }
                        .disabled(store.currentLocation == nil)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Favorites", systemImage: "star") {
                            showFavorites = true
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Chat", systemImage: "bubble.left.and.bubble.right") {
                            gaugeBotStore.send(.setChatPresented(true))
                        }
                    }
                }
                .sheet(isPresented: $gaugeBotStore.chatIsPresented.sending(\.setChatPresented)) {
                    NavigationStack {
                        GaugeBotChatView(store: gaugeBotStore)
                            .presentationDetents([.medium, .large], selection: $chatDetent)
                            .navigationTitle("GaugeBot")
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Close", systemImage: "xmark") {
                                        gaugeBotStore.send(.setChatPresented(false))
                                    }
                                }
                            }
                    }
                }
                .sheet(isPresented: $showFavorites) {
                    NavigationStack {
                        FavoriteGaugesView(store: favoritesStore)
                            .presentationDetents([.medium, .large], selection: $favoritesDetent)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Close", systemImage: "xmark") {
                                        showFavorites = false
                                    }
                                }
                            }
                    }
                }
                .sheet(isPresented: .constant(true)) {
                    GaugeListSheet(store: store)
                        .presentationDetents([.height(120), .medium, .large], selection: $gaugeListDetent)
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                        .interactiveDismissDisabled()
                }
                .trackView("GaugeSearch")
        } destination: { store in
            switch store.case {
            case .gaugeDetail(let gaugeDetailStore):
                GaugeDetail(store: gaugeDetailStore)
            }
        }
    }

    // MARK: Private

    @State private var chatDetent: PresentationDetent = .large
    @State private var favoritesDetent: PresentationDetent = .large
    @State private var gaugeListDetent: PresentationDetent = .height(120)
    @State private var showFavorites = false

    @ViewBuilder
    private func mapContent() -> some View {
        switch store.initialized {
        case .initial, .loading:
            ContinuousSpinner()
                .task {
                    store.send(.initialize)
                }
        case .loaded(let isInitialized), .reloading(let isInitialized):
            if isInitialized {
                GaugeSearchMap(store: store)
            } else {
                UtilityBlockView(kind: .error("Failed to load map"))
            }
        case .error(let error):
            UtilityBlockView(kind: .error(error.localizedDescription))
        }
    }
}

// MARK: - Preview

#Preview {
    GaugeSearch(
        store: Store(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        },
        gaugeBotStore: Store(initialState: GaugeBotReducer.State()) {
            GaugeBotReducer()
        },
        favoritesStore: Store(initialState: FavoriteGaugesFeature.State()) {
            FavoriteGaugesFeature()
        })
}
