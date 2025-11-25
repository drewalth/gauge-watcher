//
//  GaugeReadingChartControls.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import AccessibleUI
import ComposableArchitecture
import GaugeDrivers
import GaugeSources
import Loadable
import SwiftUI
import UIAppearance

struct GaugeReadingChartControls: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeDetailFeature>

    var chartDescription: String {
        switch store.readings {
        case .loaded(let readings):
            // if there is only one reading, return the date and time
            if readings.count == 1 {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, h:mm a"
                return formatter.string(from: readings.first?.createdAt ?? Date())
            }

            let (last, first) = getStartAndEndDates(readings)
            return "\(last) to \(first)"
        default:
            return "Readings within the \(store.selectedTimePeriod.description.lowercased())"
        }
    }

    var body: some View {
        HStack {
            Text(chartDescription)
                .font(.caption2)
                .bold()
                .foregroundColor(.secondary)
                .accessibleHeading(level: 2)
            Spacer()
            Menu {
                Picker("Date Range", selection: $store.selectedTimePeriod.sending(\.setSelectedTimePeriod)) {
                    ForEach(TimePeriod.PredefinedPeriod.allCases, id: \.self) { timePeriod in
                        Text(timePeriod.description)
                            .tag(timePeriod)
                    }
                }.accessiblePicker(
                    label: "Time period",
                    selectedOption: $store.selectedTimePeriod.sending(\.setSelectedTimePeriod),
                    options: TimePeriod.PredefinedPeriod.allCases,
                    hint: "Select a time period")
                Divider()
                Picker("Metric", selection: metricBinding()) {
                    ForEach(store.availableMetrics ?? [], id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .accessiblePicker(
                    label: "Metric",
                    selectedOption: metricBinding(),
                    options: store.availableMetrics ?? [],
                    hint: "Select a metric")
            } label: {
                Label("Filter", systemImage: "slider.horizontal.3")
                    .labelStyle(IconOnlyLabelStyle())
                    .foregroundColor(.white)
                    .buttonStyle(OutlinedButtonStyle())
            }.disabled(store.gauge.isLoadingOrReloading() || store.readings.isLoadingOrReloading())
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: 38, maxHeight: 38)
        }
    }

    func metricBinding() -> Binding<GaugeSourceMetric> {
        Binding<GaugeSourceMetric>(
            get: {
                store.selectedMetric ?? .cfs
            },
            set: { newValue in
                store.send(.setSelectedMetric(newValue))
            })
    }

    // MARK: Private

    private func getStartAndEndDates(_ readings: [GaugeReadingRef]) -> (last: String, first: String) {
        // if selected time frame is 24hrs, return just the month, day and time (no year)
        if store.selectedTimePeriod == .last24Hours {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return (
                formatter.string(from: readings.last?.createdAt ?? Date()),
                formatter.string(from: readings.first?.createdAt ?? Date()))
        }

        // format date strings as "MM/dd"
        return (
            readings.last?.createdAt.formatted(date: .abbreviated, time: .omitted) ?? "-",
            readings.first?.createdAt.formatted(date: .abbreviated, time: .omitted) ?? "-")
    }
}
