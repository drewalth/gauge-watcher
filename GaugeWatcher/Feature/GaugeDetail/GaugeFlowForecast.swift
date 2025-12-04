//
//  GaugeFlowForecast.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/28/25.
//

import Charts
import ComposableArchitecture
import Loadable
import SwiftUI
import UIComponents

struct GaugeFlowForecast: View {

    // MARK: Internal

    var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        VStack(spacing: 0) {
            mainContent()
        }
    }

    // MARK: Private

    private var unavailableView: some View {
        ContentUnavailableView(
            "Forecast Not Available",
            systemImage: "chart.line.downtrend.xyaxis",
            description: Text("Flow forecasting is currently only available for USGS gauges."))
    }

    @ViewBuilder
    private var forecastContent: some View {
        switch store.forecast {
        case .initial, .loading:
            loadingView
        case .loaded(let forecast), .reloading(let forecast):
            if forecast.isEmpty {
                emptyForecastView
            } else {
                forecastChart(forecast)
            }
        case .error(let error):
            UtilityBlockView(kind: .error(error.localizedDescription))
        }
    }

    private var loadingView: some View {
        VStack(alignment: .center) {
            ContinuousSpinner()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var emptyForecastView: some View {
        UtilityBlockView(
            title: "No forecast data",
            message: "Unable to generate forecast with available historical data.",
            kind: .empty)
    }

    @ViewBuilder
    private func mainContent() -> some View {
        switch store.forecastAvailable {
        case .initial, .loading:
            loadingView
        case .loaded(let isAvailable), .reloading(let isAvailable):
            if isAvailable {
                forecastContent
                    .task {
                        store.send(.getForecast)
                    }
            } else {
                unavailableView
            }
        case .error(let err):
            UtilityBlockView(kind: .error(err.localizedDescription))
        }
    }

    private func forecastChart(_ forecast: [ForecastDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Flow Forecast")
                    .font(.headline)
                Text("Next 7 Days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Chart(forecast) { dataPoint in
                // Error bound area (confidence interval)
                AreaMark(
                    x: .value("Date", dataPoint.index),
                    yStart: .value("Lower Bound", dataPoint.lowerErrorBound),
                    yEnd: .value("Upper Bound", dataPoint.upperErrorBound))
                    .foregroundStyle(.blue.opacity(0.2))
                    .interpolationMethod(.catmullRom)

                // Forecast line
                LineMark(
                    x: .value("Date", dataPoint.index),
                    y: .value("Flow", dataPoint.value))
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                // Data points
                PointMark(
                    x: .value("Date", dataPoint.index),
                    y: .value("Flow", dataPoint.value))
                    .foregroundStyle(.blue)
                    .symbolSize(30)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            VStack(alignment: .center, spacing: 2) {
                                Text(date, format: .dateTime.month(.abbreviated))
                                    .font(.caption2)
                                Text(date, format: .dateTime.day())
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        AxisGridLine()
                        AxisTick()
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let flowValue = value.as(Double.self) {
                            Text(formatFlowValue(flowValue))
                                .font(.caption)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxisLabel("Flow (CFS)", position: .leading, alignment: .center)
            .frame(height: 300)
            .padding(.horizontal)

            // Legend
            HStack(spacing: 20) {
                Label {
                    Text("Forecast")
                        .font(.caption)
                } icon: {
                    Rectangle()
                        .fill(.blue)
                        .frame(width: 20, height: 2)
                }

                Label {
                    Text("Confidence Interval")
                        .font(.caption)
                } icon: {
                    Rectangle()
                        .fill(.blue.opacity(0.2))
                        .frame(width: 20, height: 10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func formatFlowValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}
