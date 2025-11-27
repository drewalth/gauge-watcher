//
//  GaugeSearchMap.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import AppTelemetry
import ComposableArchitecture
import GaugeSources
import Loadable
import MapKit
import SwiftUI

// MARK: - GaugeSearchMap

struct GaugeSearchMap: View {

    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        ClusteredMapView(
            gauges: store.results.unwrap() ?? [],
            store: store,
            userLocation: store.currentLocation,
            shouldRecenter: store.shouldRecenterMap)
        .ignoresSafeArea(.all)
        .trackView("GaugeSearchMap")
        .toolbar {
            // Recenter button - only show if user location is available
            if store.currentLocation != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.recenterOnUserLocation)
                    } label: {
                        Label("Center on Location", systemImage: "location.fill")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
    }
}
