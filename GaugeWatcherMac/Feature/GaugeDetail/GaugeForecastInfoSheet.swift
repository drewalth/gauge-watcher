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
        InfoSheetView(title: "Forecast", onClose: onClose) {
            Section {
                Text(
                    "This chart displays a forecasted flow rate for the next seven days. Forecasts default to discharge (CFS), if available, and will fall back to gauge height (FT) if not.\n\nPlease note that forecasts are **estimates** and may not be accurate. Always check the current conditions before making any decisions based on this data.")
            }
            Section("Availability") {
                Text(
                    "Forecasting is only available for USGS gauge stations and even then, not all gauges will be able to provide forecasts. If you don't see a forecast for a gauge, it's likely due to insufficient data.")
            }
            Section("Contributing") {
                Text(
                    "If you have any feedback or suggestions for improving the forecast feature, please let us know!\n\nFlow forecasting is a GaugeWatcher open source project. If you're interested in improving this functionality or seeing how it works, please visit [the project on GitHub](https://github.com/drewalth/gauge-watcher).")
            }
        }
    }

    // MARK: Private

    private let onClose: () -> Void

}

#Preview {
    GaugeForecastInfoSheet(onClose: {
        print("close")
    })
}
