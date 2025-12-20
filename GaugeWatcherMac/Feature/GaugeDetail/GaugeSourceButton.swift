//
//  GaugeSourceButton.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/20/25.
//
import SharedFeatures
import SwiftUI
import AccessibleUI

struct GaugeSourceButton: View {
    
    private let hasGaugeSourceURL: Bool
    private let store: StoreOf<GaugeDetailFeature>
    
    init(store: StoreOf<GaugeDetailFeature>) {
        self.store = store
        self.hasGaugeSourceURL = store.gauge.unwrap()?.sourceURL != nil
    }

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
}
