//
//  GaugeReadingChart.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import AccessibleUI
import Algorithms
import Charts
import ComposableArchitecture
import GaugeDrivers
import GaugeSources
import Loadable
import SharedFeatures
import SwiftUI
import UIComponents

// MARK: - GaugeReadingChart

struct GaugeReadingChart: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        VStack(alignment: .center) {
            content()
        }.frame(minHeight: 300)
    }

    // MARK: Private

    @ViewBuilder
    private func content() -> some View {
        switch store.readings {
        case .initial, .loading:
            VStack(alignment: .center) {
                ContinuousSpinner()
            }.frame(maxWidth: .infinity, alignment: .center)
        case .loaded, .reloading:
            chartContent()
        case .error(let error):
            Text(error.localizedDescription)
        }
    }

    @ViewBuilder
    private func chartContent() -> some View {
        VStack(spacing: 16) {
            let formattedReadings = getReadings(for: store)
            GaugeReadingChartControls(store: store)
            Chart(formattedReadings, id: \.id) { reading in
                AreaMark(
                    x: .value("Day", reading.createdAt),
                    y: .value("Reading", reading.value))
                    .lineStyle(StrokeStyle(lineWidth: 2.0))
                    .interpolationMethod(.cardinal)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(1.0),
                                Color.accentColor.opacity(0.5)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom))
            }.chartXAxis(.automatic)
            .chartYAxis(.automatic)
            .animation(.default, value: formattedReadings)
        }
    }
}

/// Returns the filtered readings for the selected time period and metric
/// It will also strideBy the selected time period. There can be thousands of readings,
/// so to not overwhelm the chart, we will stride by the selected time period using swift-algorithms.
private func getReadings(for store: StoreOf<GaugeDetailFeature>) -> [GaugeReadingRef] {
    let readings = store.readings.unwrap() ?? []
    let timePeriod = store.selectedTimePeriod

    guard let selectedMetric = store.selectedMetric else {
        return []
    }

    let filteredReadings = readings
        .filter {
            isInTimePeriod(reading: $0, timePeriod: .predefined(timePeriod)) && $0.metric.uppercased() == selectedMetric.rawValue
        }

    if store.selectedTimePeriod == .last24Hours {
        return filteredReadings
    }

    return filteredReadings.striding(by: timePeriod.stride).map { $0 }
}
