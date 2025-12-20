//
//  GaugeLocationTile.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/20/25.
//

import AccessibleUI
import MapKit
import SharedFeatures
import SwiftUI

struct GaugeLocationTile: View {

    // MARK: Lifecycle

    init(_ gauge: GaugeRef, store: StoreOf<GaugeDetailFeature>) {
        self.gauge = gauge
        _store = Bindable(store)
    }

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Location", systemImage: "map.fill")
                .font(.headline)

            Map(position: $mapCameraPosition, interactionModes: []) {
                Marker(gauge.name, coordinate: CLLocationCoordinate2D(
                        latitude: gauge.latitude,
                        longitude: gauge.longitude))
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onAppear {
                mapCameraPosition = .region(MKCoordinateRegion(
                                                center: CLLocationCoordinate2D(
                                                    latitude: gauge.latitude,
                                                    longitude: gauge.longitude),
                                                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)))
            }

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lat")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(gauge.latitude, format: .number.precision(.fractionLength(4)))
                        .font(.system(.caption, design: .monospaced))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lon")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(gauge.longitude, format: .number.precision(.fractionLength(4)))
                        .font(.system(.caption, design: .monospaced))
                }
                Spacer()
                // open in maps button
                Button {
                    store.send(.openInMaps)
                } label: {
                    Label("Open in Maps", systemImage: "map.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .modifier(OutlinedTileModifier())
    }

    // MARK: Private

    @State private var mapCameraPosition: MapCameraPosition = .automatic

    private let gauge: GaugeRef

}

#Preview("With Gauge") {
    GaugeLocationTile(
        GaugeRef(
            id: 1,
            name: "Test Gauge",
            siteID: "1234567890",
            metric: .cfs,
            country: "US",
            state: "CA",
            zone: "1234567890",
            source: .usgs,
            favorite: false,
            primary: false,
            latitude: 37.7749,
            longitude: -122.4194,
            updatedAt: Date(),
            createdAt: Date()),
        store: StoreOf<GaugeDetailFeature>(initialState: GaugeDetailFeature.State(1), reducer: {
            GaugeDetailFeature()
        }))
}
