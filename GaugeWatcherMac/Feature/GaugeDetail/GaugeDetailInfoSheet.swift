//
//  GaugeDetailInfoSheet.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 10/18/24.
//

import SharedFeatures
import SwiftUI
import UIComponents

struct GaugeDetailInfoSheet: View {

    // MARK: Lifecycle

    public init(gauge: GaugeRef? = nil, onClose: @escaping () -> Void) {
        self.gauge = gauge
        self.onClose = onClose
    }

    // MARK: Internal

    var body: some View {
        InfoSheetView(title: "Help", onClose: onClose) {
            if let gauge {
                Section {
                    Text(gauge.name).font(.callout)
                }
            }
            Section("Data refresh") {
                Text(
                    """
          Data is fetched from the server when a gauge has not been updated in 30 minutes.\n\nA gauge is considered updated if there are new flow readings. If a fetch is made and there are no new readings, the gauge will not be updated on your device.
          """).font(.body)
            }

            singleReadingPerFetch()

            Section("Metrics") {
                Text(
                    "CFS = Cubic Feet per Second\nFT = Feet (Height)\n\nCMS = Cubic Meters per Second\nM = Meters (Height)").font(.body)
            }

            Section("Unresponsive Gauges") {
                Text(
                    "A gauge station is considered unresponsive if it returns values of -999999 for either discharge or height readings.")
                    .font(.body)
            }
        }
    }

    // MARK: Private

    private let gauge: GaugeRef?
    private let onClose: () -> Void

    @ViewBuilder
    private func singleReadingPerFetch() -> some View {
        if let gauge {
            if gauge.source == .dwr || gauge.source == .lawa {
                Section("Single Reading Per Fetch") {
                    Text(
                        """
            This gauge station only provides one reading per fetch. This means that the gauge will only return the most recent reading, rather than a list of readings. After a fetch, the gauge will not be updated again until a new reading is available.
            """).font(.body)
                }
            } else {
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

}

#Preview {
    GaugeDetailInfoSheet {
        print("close")
    }
}
