//
//  GaugeDetailView.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//

import SQLiteData
import SwiftUI

struct GaugeDetailView: View {

    // MARK: Lifecycle

    init(_ gaugeID: Int) {
        self.gaugeID = gaugeID
    }

    // MARK: Internal

    @FetchOne var gauge: Gauge?

    var body: some View {
        List {
            content()
        }
        .task(id: gaugeID) {
            await updateQuery()
        }
    }

    @ViewBuilder
    func content() -> some View {
        if $gauge.isLoading {
            ProgressView()
        } else {
            if let gauge {
                Text(gauge.name)
            } else {
                Text("Gauge not found")
            }
        }
    }

    // MARK: Private

    private let gaugeID: Int

    private func updateQuery() async {
        do {
            try await $gauge.load(
                Gauge
                    .where { $0.id == #bind(gaugeID) })

        } catch {
            print(error.localizedDescription)
        }
    }
}
