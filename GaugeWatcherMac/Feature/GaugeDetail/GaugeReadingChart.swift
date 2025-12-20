//
//  GaugeReadingChart.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import Algorithms
import Charts
import GaugeDrivers
import GaugeSources
import Loadable
import SharedFeatures
import SwiftUI

// MARK: - GaugeReadingChart

struct GaugeReadingChart: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chartHeader
            chartContent
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

    // Fixed heights for consistent layout
    private let chartHeight: CGFloat = 250
    private let tooltipHeight: CGFloat = 64

    @State private var selectedReading: GaugeReadingRef?
    @State private var chartHoveredPosition: CGPoint?

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.4),
                Color.accentColor.opacity(0.1),
                Color.accentColor.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom)
    }

    private var lineGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing)
    }

    private var filteredReadings: [GaugeReadingRef] {
        getFilteredReadings(for: store)
    }

    private var chartDateRangeDescription: String {
        guard let readings = store.readings.unwrap(), !readings.isEmpty else {
            return "No data"
        }

        let filtered = filteredReadings
        guard let first = filtered.first, let last = filtered.last else {
            return store.selectedTimePeriod.description
        }

        if store.selectedTimePeriod == .last24Hours {
            return "\(last.createdAt.formatted(date: .omitted, time: .shortened)) – \(first.createdAt.formatted(date: .omitted, time: .shortened))"
        }

        return "\(last.createdAt.formatted(date: .abbreviated, time: .omitted)) – \(first.createdAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private var xAxisStride: Calendar.Component {
        switch store.selectedTimePeriod {
        case .last24Hours:
            return .hour
        case .last7Days:
            return .day
        case .last30Days, .last90Days:
            return .day
        }
    }

    private var xAxisStrideCount: Int {
        switch store.selectedTimePeriod {
        case .last24Hours:
            return 4
        case .last7Days:
            return 1
        case .last30Days:
            return 5
        case .last90Days:
            return 14
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch store.selectedTimePeriod {
        case .last24Hours:
            return .dateTime.hour()
        case .last7Days:
            return .dateTime.weekday(.abbreviated)
        case .last30Days, .last90Days:
            return .dateTime.month(.abbreviated).day()
        }
    }

    @ViewBuilder
    private var chartHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Flow History")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(chartDateRangeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            GaugeReadingChartControls(store: store)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var chartContent: some View {
        switch store.gauge {
        case .initial, .loading:
            loadingView
        case .loaded, .reloading:
            switch store.readings {
            case .initial, .loading:
                loadingView
            case .loaded, .reloading:
                chartView
            case .error(let error):
                errorView(error)
            }
        case .error(let error):
            errorView(error)
            
        }
    }

    private var loadingView: some View {
        VStack(spacing: 0) {
            // Chart skeleton area - same height as real chart
            chartSkeleton
                .frame(height: chartHeight)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // Tooltip placeholder - same height as real tooltip
            Rectangle()
                .fill(.clear)
                .frame(height: tooltipHeight)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    private var chartSkeleton: some View {
        ZStack {
            // Background grid lines skeleton
            VStack(spacing: 0) {
                ForEach(0 ..< 5, id: \.self) { _ in
                    Spacer()
                    Rectangle()
                        .fill(.secondary.opacity(0.1))
                        .frame(height: 1)
                }
                Spacer()
            }

            // Loading indicator overlay
            VStack {
                ProgressView()
                    .scaleEffect(0.5)
                Text("Loading readings...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    private var chartView: some View {
        let readings = filteredReadings

        VStack(alignment: .leading, spacing: 0) {
            if readings.isEmpty {
                emptyView
                    .frame(height: chartHeight)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            } else {
                Chart(readings, id: \.id) { reading in
                    AreaMark(
                        x: .value("Time", reading.createdAt),
                        y: .value("Value", reading.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(areaGradient)

                    LineMark(
                        x: .value("Time", reading.createdAt),
                        y: .value("Value", reading.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(lineGradient)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                    if let selected = selectedReading, selected.id == reading.id {
                        PointMark(
                            x: .value("Time", reading.createdAt),
                            y: .value("Value", reading.value))
                            .foregroundStyle(.white)
                            .symbolSize(80)

                        RuleMark(x: .value("Time", reading.createdAt))
                            .foregroundStyle(.white.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride, count: xAxisStrideCount)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                VStack(spacing: 2) {
                                    Text(date, format: xAxisFormat)
                                        .font(.caption2)
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
                                    chartHoveredPosition = location
                                    updateSelectedReading(at: location, proxy: proxy, geometry: geometry)
                                case .ended:
                                    chartHoveredPosition = nil
                                    selectedReading = nil
                                }
                            }
                    }
                }
                .chartBackground { _ in
                    LinearGradient(
                        colors: [.accentColor.opacity(0.05), .clear],
                        startPoint: .top,
                        endPoint: .bottom)
                }
                .frame(height: chartHeight)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            // Tooltip area - fixed height regardless of content
            tooltipArea
                .frame(height: tooltipHeight)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    private func getSelectedReading() -> GaugeReadingRef? {
        if filteredReadings.count == 1 {
            return filteredReadings.first
        }
        return selectedReading
    }
    
    @ViewBuilder
    private var tooltipArea: some View {
        if let selected = getSelectedReading() {
            tooltipView(for: selected)
        } else {
            // Empty placeholder matching tooltip container style
            HStack {
                Image(systemName: "cursorarrow.rays")
                    .foregroundStyle(.tertiary)
                Text("Hover over chart for details")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(height: tooltipHeight * 0.5)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No Readings",
            systemImage: "chart.line.downtrend.xyaxis",
            description: Text("No data available for the selected time period"))
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 0) {
            ContentUnavailableView(
                "Error Loading Data",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription))
                .frame(height: chartHeight)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            Color.clear
                .frame(height: tooltipHeight)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func tooltipView(for reading: GaugeReadingRef) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Value")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(reading.value, format: .number.precision(.fractionLength(2)))
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                    Text(reading.metric)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .frame(height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(reading.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.system(.body, design: .monospaced))
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
            return (value / 1000).formatted(.number.precision(.fractionLength(0))) + "k"
        } else if value >= 1000 {
            return (value / 1000).formatted(.number.precision(.fractionLength(1))) + "k"
        } else if value >= 100 {
            return value.formatted(.number.precision(.fractionLength(0)))
        } else {
            return value.formatted(.number.precision(.fractionLength(1)))
        }
    }

    private func updateSelectedReading(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let xPosition = location.x - geometry[plotFrame].origin.x

        guard let date: Date = proxy.value(atX: xPosition) else { return }

        let readings = filteredReadings
        guard !readings.isEmpty else { return }

        // Find the closest reading to the hovered date
        let closest = readings.min { reading1, reading2 in
            abs(reading1.createdAt.timeIntervalSince(date)) < abs(reading2.createdAt.timeIntervalSince(date))
        }

        selectedReading = closest
    }
}

// MARK: - Helper Functions

private func getFilteredReadings(for store: StoreOf<GaugeDetailFeature>) -> [GaugeReadingRef] {
    let readings = store.readings.unwrap() ?? []
    let timePeriod = store.selectedTimePeriod

    guard let selectedMetric = store.selectedMetric else {
        return []
    }

    let filteredReadings = readings.filter {
        isInTimePeriod(reading: $0, timePeriod: .predefined(timePeriod)) &&
            $0.metric.uppercased() == selectedMetric.rawValue
    }

    if store.selectedTimePeriod == .last24Hours {
        return filteredReadings
    }

    return filteredReadings.striding(by: timePeriod.stride).map { $0 }
}

private func isInTimePeriod(reading: GaugeReadingRef, timePeriod: TimePeriod) -> Bool {
    switch timePeriod {
    case .predefined(let predefinedPeriod):
        return reading.createdAt.isInTimePeriod(predefinedPeriod: predefinedPeriod)
    case .custom(let start, let end):
        return reading.createdAt >= start && reading.createdAt <= end
    }
}

// MARK: - Date Extension

extension Date {
    func isInTimePeriod(predefinedPeriod: TimePeriod.PredefinedPeriod) -> Bool {
        let now = Date()
        let interval: TimeInterval = switch predefinedPeriod {
        case .last24Hours:
            -86400
        case .last7Days:
            -604800
        case .last30Days:
            -2592000
        case .last90Days:
            -7776000
        }
        return self >= now.addingTimeInterval(interval)
    }
}
