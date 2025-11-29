//
//  GaugeFlowForecast.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/28/25.
//

import SwiftUI
import ComposableArchitecture

struct GaugeFlowForecast:View {
    var store: StoreOf<GaugeFlowForecastFeature>
    
    var body: some View {
        Text("Hello")
            .task {
                store.send(.load)
            }
    }
}
