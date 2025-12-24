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

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
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
                .sheet(isPresented: $gaugeListSheetPresented) {
                    GaugeListSheet(store: store, selectedDetent: $gaugeListDetent)
                        .presentationDetents([.height(56), .medium, .large], selection: $gaugeListDetent)
                        .presentationDragIndicator(.hidden)
                        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                        .presentationCornerRadius(20)
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
    @State private var gaugeListDetent: PresentationDetent = .height(56)
    @State private var gaugeListSheetPresented = true

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
