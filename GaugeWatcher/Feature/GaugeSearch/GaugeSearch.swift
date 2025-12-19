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
    @State private var selectedDetent: PresentationDetent = .large

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            Group {
                content()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Chat", systemImage: "bubble.left.and.bubble.right") {
                            gaugeBotStore.send(.setChatPresented(true))
                        }
                    }
                }
                    .sheet(isPresented: $gaugeBotStore.chatIsPresented.sending(\.setChatPresented)) {
                        NavigationStack {
                            GaugeBotChatView(store: gaugeBotStore)
                                .presentationDetents([.medium, .large], selection: $selectedDetent)
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

    @ViewBuilder
    private func content() -> some View {
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
