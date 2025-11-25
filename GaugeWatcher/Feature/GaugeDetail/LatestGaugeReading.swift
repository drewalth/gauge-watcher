//
//  LatestGaugeReading.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import ComposableArchitecture
import Loadable
import SwiftUI

struct LatestGaugeReading: View {
    var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        switch store.readings {
        case .loading, .initial:
            ProgressView()
        case .loaded(let readings), .reloading(let readings):
            if let reading = readings.first {
                HStack(alignment: .bottom) {
                    Text("\(reading.value.formatted(.number.precision(.fractionLength(2))))")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("\(reading.metric)")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(reading.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No latest reading")
            }
        case .error(let error):
            Text(error.localizedDescription)
        }
    }
}
