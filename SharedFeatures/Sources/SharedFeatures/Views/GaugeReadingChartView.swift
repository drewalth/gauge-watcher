//
//  GaugeReadingChartView.swift
//  SharedFeatures
//
//  A polished chart for displaying gauge readings with platform-adaptive interaction.
//

import Algorithms
import Charts
import GaugeDrivers
import GaugeSources
import SwiftUI

// MARK: - GaugeReadingChartView

/// A polished chart view for displaying gauge readings.
/// Supports hover on macOS and touch on iOS.
public struct GaugeReadingChartView: View {

    // MARK: Lifecycle

    public init(
        readings: [GaugeReadingRef],
        selectedTimePeriod: TimePeriod.PredefinedPeriod,
        selectedMetric: GaugeSourceMetric?,
        isLoading: Bool,
        isInactive: Bool,
        onTimePeriodChange: @escaping (TimePeriod.PredefinedPeriod) -> Void,
        onMetricChange: @escaping (GaugeSourceMetric) -> Void,
        availableMetrics: [GaugeSourceMetric]) {
        self.readings = readings
        self.selectedTimePeriod = selectedTimePeriod
        self.selectedMetric = selectedMetric
        self.isLoading = isLoading
        self.isInactive = isInactive
        self.onTimePeriodChange = onTimePeriodChange
        self.onMetricChange = onMetricChange
        self.availableMetrics = availableMetrics
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chartHeader
            chartContent
        }
        .outlinedTile()
    }

    // MARK: Private

    @State private var selectedReading: GaugeReadingRef?

    private let readings: [GaugeReadingRef]
    private let selectedTimePeriod: TimePeriod.PredefinedPeriod
    private let selectedMetric: GaugeSourceMetric?
    private let isLoading: Bool
    private let isInactive: Bool
    private let onTimePeriodChange: (TimePeriod.PredefinedPeriod) -> Void
    private let onMetricChange: (GaugeSourceMetric) -> Void
    private let availableMetrics: [GaugeSourceMetric]

    private let chartHeight: CGFloat = 250
    private let tooltipHeight: CGFloat = 64

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
        guard let metric = selectedMetric else { return [] }

        let filtered = readings.filter {
            isInTimePeriod(reading: $0, timePeriod: selectedTimePeriod) &&
                $0.metric.uppercased() == metric.rawValue
        }

        if selectedTimePeriod == .last24Hours {
            return filtered
        }

        return filtered.striding(by: selectedTimePeriod.stride).map { $0 }
    }

    private var chartDateRangeDescription: String {
        guard !readings.isEmpty else { return "No data" }

        let filtered = filteredReadings
        guard let first = filtered.first, let last = filtered.last else {
            return selectedTimePeriod.description
        }

        if selectedTimePeriod == .last24Hours {
            return "\(last.createdAt.formatted(date: .omitted, time: .shortened)) – \(first.createdAt.formatted(date: .omitted, time: .shortened))"
        }

        return "\(last.createdAt.formatted(date: .abbreviated, time: .omitted)) – \(first.createdAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private var xAxisStride: Calendar.Component {
        switch selectedTimePeriod {
        case .last24Hours:
            .hour
        case .last7Days, .last30Days, .last90Days:
            .day
        }
    }

    private var xAxisStrideCount: Int {
        switch selectedTimePeriod {
        case .last24Hours:
            4
        case .last7Days:
            1
        case .last30Days:
            5
        case .last90Days:
            14
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedTimePeriod {
        case .last24Hours:
            .dateTime.hour()
        case .last7Days:
            .dateTime.weekday(.abbreviated)
        case .last30Days, .last90Days:
            .dateTime.month(.abbreviated).day()
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

            chartControls
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var chartControls: some View {
        HStack(spacing: 8) {
            // Metric picker
            if availableMetrics.count > 1 {
                Menu {
                    ForEach(availableMetrics, id: \.self) { metric in
                        Button(metric.rawValue) {
                            onMetricChange(metric)
                        }
                    }
                } label: {
                    Text(selectedMetric?.rawValue ?? "—")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .menuStyle(.borderlessButton)
                .frame(minWidth: 50)
            }

            // Time period picker
            Menu {
                ForEach(TimePeriod.PredefinedPeriod.allCases, id: \.self) { period in
                    Button(period.description) {
                        onTimePeriodChange(period)
                    }
                }
            } label: {
                Text(selectedTimePeriod.description)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .menuStyle(.borderlessButton)
            .frame(minWidth: 80)
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if isInactive {
            inactiveGaugeView
        } else if isLoading {
            loadingView
        } else {
            chartView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 0) {
            chartSkeleton
                .frame(height: chartHeight)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            Rectangle()
                .fill(.clear)
                .frame(height: tooltipHeight)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    private var chartSkeleton: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(0 ..< 5, id: \.self) { _ in
                    Spacer()
                    Rectangle()
                        .fill(.secondary.opacity(0.1))
                        .frame(height: 1)
                }
                Spacer()
            }

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
        let chartReadings = filteredReadings

        VStack(alignment: .leading, spacing: 0) {
            if chartReadings.isEmpty {
                emptyView
                    .frame(height: chartHeight)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            } else {
                Chart(chartReadings, id: \.id) { reading in
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
                #if os(macOS)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(.rect)
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    updateSelectedReading(at: location, proxy: proxy, geometry: geometry)
                                case .ended:
                                    selectedReading = nil
                                }
                            }
                    }
                }
                #else
                .chartOverlay { proxy in
                GeometryReader { geometry in
                Rectangle()
                .fill(.clear)
                .contentShape(.rect)
                .gesture(
                DragGesture(minimumDistance: 0)
                .onChanged { value in
                updateSelectedReading(at: value.location, proxy: proxy, geometry: geometry)
                }
                .onEnded { _ in
                selectedReading = nil
                })
                }
                }
                #endif
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

            tooltipArea
                .frame(height: tooltipHeight)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var tooltipArea: some View {
        if let selected = getDisplayReading() {
            tooltipView(for: selected)
        } else {
            #if os(macOS)
            let hintText = "Hover over chart for details"
            #else
            let hintText = "Touch chart for details"
            #endif
            HStack {
                Image(systemName: "cursorarrow.rays")
                    .foregroundStyle(.tertiary)
                Text(hintText)
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

    private var inactiveGaugeView: some View {
        VStack(spacing: 0) {
            ContentUnavailableView(
                "No Historical Data",
                systemImage: "chart.line.downtrend.xyaxis",
                description: Text("This gauge is inactive and has no recent readings to display."))
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

    private func getDisplayReading() -> GaugeReadingRef? {
        if filteredReadings.count == 1 {
            return filteredReadings.first
        }
        return selectedReading
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

        let chartReadings = filteredReadings
        guard !chartReadings.isEmpty else { return }

        let closest = chartReadings.min { reading1, reading2 in
            abs(reading1.createdAt.timeIntervalSince(date)) < abs(reading2.createdAt.timeIntervalSince(date))
        }

        selectedReading = closest
    }

    private func isInTimePeriod(reading: GaugeReadingRef, timePeriod: TimePeriod.PredefinedPeriod) -> Bool {
        let now = Date()
        let interval: TimeInterval = switch timePeriod {
        case .last24Hours:
            -86400
        case .last7Days:
            -604800
        case .last30Days:
            -2592000
        case .last90Days:
            -7776000
        }
        return reading.createdAt >= now.addingTimeInterval(interval)
    }
}

// MARK: - Preview

#Preview {
    GaugeReadingChartView(
        readings: [],
        selectedTimePeriod: .last7Days,
        selectedMetric: .cfs,
        isLoading: false,
        isInactive: false,
        onTimePeriodChange: { _ in },
        onMetricChange: { _ in },
        availableMetrics: [.cfs, .feetHeight])
        .frame(height: 400)
        .padding()
}
