//
//  GaugeReadingChart.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import ComposableArchitecture
import Loadable
import SwiftUI
import Charts
import GaugeDrivers
import Algorithms
import GaugeSources

struct GaugeReadingChart: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        VStack {
            content()
            
        }.frame(minHeight: 300)
    }

    // MARK: Private

    @ViewBuilder
    private func content() -> some View {
        switch store.readings {
        case .initial, .loading:
            ProgressView()
        case .loaded, .reloading:
            VStack(spacing: 16) {
                HStack {
                    Picker("Time Period", selection: $store.selectedTimePeriod.sending(\.setSelectedTimePeriod)) {
                        ForEach(TimePeriod.PredefinedPeriod.allCases, id: \.rawValue) { timePeriod in
                            Text(timePeriod.description)
                                .tag(timePeriod)
                        }
                    }.pickerStyle(.segmented)
                   
                }
                let formattedReadings = getReadings(for: store)
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
        case .error(let error):
            Text(error.localizedDescription)
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
    
    let filteredReadings = readings.filter { isInTimePeriod(reading: $0, timePeriod: .predefined(timePeriod)) && $0.metric.uppercased() == selectedMetric.rawValue }
    
    if store.selectedTimePeriod == .last24Hours {
        return filteredReadings
    }
    
    return filteredReadings.striding(by: timePeriod.stride).map { $0 }
}
