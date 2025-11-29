//
//  GaugeFlowForecast.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/28/25.
//

import ComposableArchitecture
import SwiftUI

struct GaugeFlowForecast: View {
    var store: StoreOf<GaugeFlowForecastFeature>

    var body: some View {
        Text("Hello")
            .task {
                store.send(.load)
            }
    }
}
