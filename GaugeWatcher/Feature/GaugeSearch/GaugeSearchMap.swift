//
//  GaugeSearchMap.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import SwiftUI

struct GaugeSearchMap: View {
    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        VStack {
            Text("map")
        }.toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.toggleMode)
                } label: {
                    Label("Mode", systemImage: store.mode == .list ? "list.bullet" : "map")
                        .labelStyle(.iconOnly)
                }
            }
        }
    }
}
