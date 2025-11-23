//
//  App.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//

import ComposableArchitecture
import SwiftUI
import Loadable

// MARK: - AppView

struct AppView: View {

    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            content()
        }
            .task {
                store.send(.initialize)
            }
    }

    @ViewBuilder
    private func content() -> some View {
        switch store.initialized {
        case .initial, .reloading, .loading:
            ProgressView()
        case .error(let error):
            VStack(alignment: .leading, spacing: 8) {
                Text("Something went wrong")
                Text(error.localizedDescription)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        case .loaded(let isInitialized):
            
            TabView {
                GaugeSearch(store: Store(initialState: GaugeSearchFeature.State(), reducer: {
                    GaugeSearchFeature()
                }))
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(1)
            }
        }
    }
}
