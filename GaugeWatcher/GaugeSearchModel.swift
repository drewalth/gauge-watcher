//
//  GaugeSearchModel.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//

import GaugeSources
import SQLiteData
import SwiftUI

@MainActor
@Observable
final class GaugeSearchModel {

    // MARK: Lifecycle

    init() {
        Task { await reloadItems() }
    }

    // MARK: Internal

    @ObservationIgnored
    @FetchAll(Gauge.order(by: \.name))
    var items

    var state = "CO" {
        didSet { Task { await reloadItems() } }
    }

    var source: GaugeSource = .usgs {
        didSet { Task { await reloadItems() } }
    }

    func reloadItems() async {
        do {
            try await $items.load(
                Gauge.where {
                    $0.source == source && $0.state == state
                }.order(by: \.name))
        } catch {
            print(error.localizedDescription)
        }
    }
}
