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
        ZStack {
            Map(
                position: $store.mapPosition.sending(\.setMapPosition),
                interactionModes: [.pan, .zoom, .rotate]) {
                ForEach(store.results.unwrap() ?? [], id: \.id) { gauge in
                    Annotation(gauge.name, coordinate: gauge.location.coordinate) {
                        GaugeMapMarker(store: store, gauge: gauge)
                    }
                    .annotationTitles(.hidden)
                }
                UserAnnotation()
            }
            .ignoresSafeArea(.all)
            .onMapCameraChange(frequency: .onEnd) { context in
                // Only report when user stops moving the map (not during animation)
                store.send(.mapRegionChanged(context.region))
            }

            // Show message when zoomed out too far
            if let region = store.mapRegion, region.span.latitudeDelta > 2.0 {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Zoom in to view gauges")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 2)
                    .padding(.bottom, 100)
                }
                .transition(.opacity)
                .animation(.easeInOut, value: store.mapRegion?.span.latitudeDelta)
            }
        }
        .trackView("GaugeSearchMap")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.toggleMode)
                } label: {
                    Label("Mode", systemImage: store.mode == .list ? "map": "list.bullet")
                        .labelStyle(.iconOnly)
                }
            }

            // Recenter button - only show if user location is available
            if let location = store.currentLocation {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            let cameraPosition = MapCameraPosition.camera(
                                MapCamera(
                                    centerCoordinate: CLLocationCoordinate2D(
                                        latitude: location.latitude,
                                        longitude: location.longitude),
                                    distance: 150_000, // ~93 miles
                                    heading: 0,
                                    pitch: 0))
                            store.send(.setMapPosition(cameraPosition))
                        }
                    } label: {
                        Label("Center on Location", systemImage: "location.fill")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
    }
}
