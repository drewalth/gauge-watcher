//
//  GaugeReadingChart.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import Loadable
import SwiftUI
import ComposableArchitecture

struct GaugeReadingChart: View {
    var store: StoreOf<GaugeDetailFeature>
    
    var body: some View {
        VStack {
            content()
        }.frame(minHeight: 300)
    }
    
    @ViewBuilder
    private func content() -> some View {
        switch store.readings {
        case .initial, .loading:
            ProgressView()
        case .loaded(let readings), .reloading(let readings):
            Text("Readings: \(readings.count)")
            if store.readings.isReloading() {
                ProgressView()
            }
        case .error(let error):
            Text(error.localizedDescription)
        }
    }
}
