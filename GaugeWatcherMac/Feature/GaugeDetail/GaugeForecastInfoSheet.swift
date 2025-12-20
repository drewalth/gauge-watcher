//
//  GaugeForecastInfoSheet.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/20/25.
//

import SwiftUI
import UIComponents

struct GaugeForecastInfoSheet: View {

    // MARK: Lifecycle

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    // MARK: Internal

    var body: some View {
        InfoSheetView(title: "Flow Forecasting", onClose: onClose) {
            overviewSection

            howItWorksSection

            limitationsSection

            availabilitySection

            openSourceSection
        }
    }

    // MARK: Private

    private let onClose: () -> Void

    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Predicts water flow for the next 7 days based on historical patterns.")
                    .font(.callout)

                HStack(spacing: 16) {
                    metricBadge(label: "CFS", description: "Primary")
                    metricBadge(label: "FT", description: "Fallback")
                }
            }
        } header: {
            Label("What You're Seeing", systemImage: "chart.line.uptrend.xyaxis")
        }
    }

    private var howItWorksSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                stepRow(
                    number: 1,
                    title: "Historical Analysis",
                    description: "Examines past readings for the gauge station")

                stepRow(
                    number: 2,
                    title: "Pattern Recognition",
                    description: "Identifies seasonal and recent flow trends")

                stepRow(
                    number: 3,
                    title: "Projection",
                    description: "Generates a 7-day forecast with confidence bounds")
            }
        } header: {
            Label("How It Works", systemImage: "gearshape.2")
        }
    }

    private var limitationsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                warningRow(
                    icon: "exclamationmark.triangle",
                    text: "Forecasts are estimates, not guarantees")

                warningRow(
                    icon: "cloud.rain",
                    text: "Cannot predict sudden weather events or dam releases")

                warningRow(
                    icon: "checkmark.shield",
                    text: "Always verify current conditions before making decisions")
            }
        } header: {
            Label("Important Limitations", systemImage: "info.circle")
        }
    }

    private var availabilitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("USGS stations only")
                        .font(.callout)
                } icon: {
                    Image(systemName: "building.columns.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                }

                Text(
                    """
          Not all USGS gauges support forecasting. Stations with insufficient \
          historical data or irregular reporting patterns won't show forecasts.
          """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Availability", systemImage: "antenna.radiowaves.left.and.right")
        }
    }

    private var openSourceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    "Forecasting is an exciting new feature of GaugeWatcher. If you're interested in improving this functionality or seeing how it works, please visit the project on GitHub.")
                    .font(.callout)

                if let url = URL(string: "https://github.com/drewalth/gauge-watcher/tree/main/server/flow-forecast") {
                    Link(destination: url) {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                            .font(.callout)
                    }
                }
            }
        } header: {
            Label("Open Source", systemImage: "chevron.left.forwardslash.chevron.right")
        }
    }

    private func metricBadge(label: String, description: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .bold()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.15), in: .capsule)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func stepRow(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .bold()
                .frame(width: 20, height: 20)
                .background(.blue.opacity(0.15), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .bold()
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func warningRow(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .font(.callout)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 20)
        }
    }

}

#Preview {
    GaugeForecastInfoSheet(onClose: { })
}
