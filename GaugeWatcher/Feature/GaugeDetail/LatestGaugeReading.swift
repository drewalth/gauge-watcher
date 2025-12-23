//
//  LatestGaugeReading.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import AppDatabase
import ComposableArchitecture
import Loadable
import SharedFeatures
import SwiftUI

struct LatestGaugeReading: View {
    var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        if let gauge = store.gauge.unwrap(), gauge.status == .inactive {
            inactiveGaugeView
        } else {
            readingsContent
        }
    }

    @ViewBuilder
    private var readingsContent: some View {
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
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(reading.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No latest reading")
            }
        case .error(let error):
            Text(error.localizedDescription)
        }
    }

    private var inactiveGaugeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Gauge Inactive", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)

            Text("This gauge is not currently reporting data. It may be offline, decommissioned, or experiencing seasonal shutdown.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.red.opacity(0.1))
        }
    }
}
