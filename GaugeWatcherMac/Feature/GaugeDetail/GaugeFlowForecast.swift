//
//  GaugeFlowForecast.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import Charts
import GaugeService
import Loadable
import SharedFeatures
import SwiftUI

// MARK: - GaugeFlowForecast

struct GaugeFlowForecast: View {

    // MARK: Internal

    var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            mainContent
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    lineWidth: 1)
        }
    }

    // MARK: Private

    @State private var selectedDataPoint: ForecastDataPoint?
    @State private var isExpanded = true

    @ViewBuilder
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.blue)

                    Text("Flow Forecast")
                        .font(.headline)

                    betaBadge
                }

                Text("7-Day ML-Powered Prediction")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var betaBadge: some View {
        Text("BETA")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(.blue.opacity(0.2))
            }
            .foregroundStyle(.blue)
    }

    @ViewBuilder
    private var mainContent: some View {
        if isExpanded {
            VStack(spacing: 0) {
                Divider()
                    .padding(.horizontal, 20)

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
                case .error(let error):
                    errorView(error)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
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
            errorView(error)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Generating forecast...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("Forecast Unavailable")
                .font(.headline)

            Text("Flow forecasting is currently only available for USGS gauges with sufficient historical data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var emptyForecastView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("Insufficient Data")
                .font(.headline)

            Text("Unable to generate forecast with the available historical data for this gauge.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var legendView: some View {
        HStack(spacing: 24) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue)
                    .frame(width: 20, height: 3)
                Text("Forecast")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue.opacity(0.2))
                    .frame(width: 20, height: 12)
                Text("Confidence Interval")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.red)

            Text("Forecast Error")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private func forecastChart(_ forecast: [ForecastDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Chart(forecast) { dataPoint in
                // Confidence interval area
                AreaMark(
                    x: .value("Date", dataPoint.index),
                    yStart: .value("Lower", dataPoint.lowerErrorBound),
                    yEnd: .value("Upper", dataPoint.upperErrorBound))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom))
                    .interpolationMethod(.catmullRom)

                // Main forecast line
                LineMark(
                    x: .value("Date", dataPoint.index),
                    y: .value("Flow", dataPoint.value))
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                // Data points
                PointMark(
                    x: .value("Date", dataPoint.index),
                    y: .value("Flow", dataPoint.value))
                    .foregroundStyle(.blue)
                    .symbolSize(selectedDataPoint?.id == dataPoint.id ? 100 : 40)

                // Selection indicator
                if let selected = selectedDataPoint, selected.id == dataPoint.id {
                    RuleMark(x: .value("Date", dataPoint.index))
                        .foregroundStyle(.blue.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            VStack(spacing: 2) {
                                Text(date, format: .dateTime.weekday(.abbreviated))
                                    .font(.caption2)
                                Text(date, format: .dateTime.day())
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.secondary)
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(.secondary.opacity(0.3))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let flowValue = value.as(Double.self) {
                            Text(formatFlowValue(flowValue))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(.secondary.opacity(0.3))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(.rect)
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                updateSelectedDataPoint(at: location, proxy: proxy, geometry: geometry, forecast: forecast)
                            case .ended:
                                selectedDataPoint = nil
                            }
                        }
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 20)
            .animation(.easeInOut(duration: 0.15), value: selectedDataPoint?.id)

            // Tooltip
            if let selected = selectedDataPoint {
                forecastTooltip(for: selected)
                    .padding(.horizontal, 20)
            }

            // Legend
            legendView
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private func forecastTooltip(for dataPoint: ForecastDataPoint) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Predicted Flow")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(dataPoint.value, format: .number.precision(.fractionLength(0)))
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                    Text("CFS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .frame(height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Date")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(dataPoint.index, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.system(.body, design: .monospaced))
            }

            Divider()
                .frame(height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Confidence Range")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(
                    "\(dataPoint.lowerErrorBound, format: .number.precision(.fractionLength(0))) – \(dataPoint.upperErrorBound, format: .number.precision(.fractionLength(0)))")
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThickMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func formatFlowValue(_ value: Double) -> String {
        if value >= 10000 {
            return String(format: "%.0fk", value / 1000)
        } else if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }

    private func updateSelectedDataPoint(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        forecast: [ForecastDataPoint]) {
        let xPosition = location.x - geometry[proxy.plotFrame!].origin.x

        guard let date: Date = proxy.value(atX: xPosition) else { return }

        let closest = forecast.min { dp1, dp2 in
            abs(dp1.index.timeIntervalSince(date)) < abs(dp2.index.timeIntervalSince(date))
        }

        selectedDataPoint = closest
    }
}
