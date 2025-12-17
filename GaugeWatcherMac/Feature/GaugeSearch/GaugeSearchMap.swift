//
//  GaugeSearchMap.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import MapKit
import SharedFeatures
import SwiftUI

// MARK: - GaugeSearchMap

struct GaugeSearchMap: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        Map(
            position: $mapPosition,
            selection: $selectedGaugeID) {
            if let gauges = store.results.unwrap() {
                ForEach(gauges) { gauge in
                    Marker(
                        gauge.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: gauge.latitude,
                            longitude: gauge.longitude))
                        .tint(.blue)
                        .tag(gauge.id)
                }
            }

            // Show user location if available
            if store.currentLocation != nil {
                UserAnnotation()
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .toolbar(removing: .title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if store.currentLocation != nil {
                    Button {
                        store.send(.recenterOnUserLocation)
                    } label: {
                        Label("Center on Location", systemImage: "location.fill")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
        .onChange(of: selectedGaugeID) { _, newValue in
            if let gaugeID = newValue {
                store.send(.goToGaugeDetail(gaugeID))
                // Clear selection after navigation
                selectedGaugeID = nil
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            store.send(.mapRegionChanged(context.region))
        }
        .onChange(of: store.shouldRecenterMap) { _, shouldRecenter in
            if shouldRecenter, let location = store.currentLocation {
                withAnimation {
                    mapPosition = .region(MKCoordinateRegion(
                                            center: CLLocationCoordinate2D(
                                                latitude: location.latitude,
                                                longitude: location.longitude),
                                            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)))
                }
                store.send(.recenterCompleted)
            }
        }
    }

    // MARK: Private

    @State private var selectedGaugeID: Int?
    @State private var mapPosition: MapCameraPosition = .automatic
}

// MARK: - Preview

#Preview {
    GaugeSearchMap(store: Store(initialState: GaugeSearchFeature.State()) {
        GaugeSearchFeature()
    })
}
