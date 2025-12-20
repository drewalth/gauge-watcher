//
//  GaugeSourceButton.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/20/25.
//
import AccessibleUI
import SharedFeatures
import SwiftUI

struct GaugeSourceButton: View {

    // MARK: Lifecycle

    init(store: StoreOf<GaugeDetailFeature>) {
        self.store = store
        hasGaugeSourceURL = store.gauge.unwrap()?.sourceURL != nil
    }

    // MARK: Internal

    var body: some View {
        Button {
            guard hasGaugeSourceURL else { return }
            store.send(.openSource)
        } label: {
            Image(systemName: "safari")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(hasGaugeSourceURL ? "Open gauge source website" : "Gauge source unavailable")
        .opacity(hasGaugeSourceURL ? 1 : 0.5)
        .accessibleButton(label: "Open gauge source website")
    }

    // MARK: Private

    private let hasGaugeSourceURL: Bool
    private let store: StoreOf<GaugeDetailFeature>

}
