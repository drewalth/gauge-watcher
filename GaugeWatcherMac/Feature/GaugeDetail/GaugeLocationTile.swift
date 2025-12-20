//
//  GaugeLocationTile.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/20/25.
//

import SwiftUI
import SharedFeatures
import MapKit

struct GaugeLocationTile: View {
    
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    private let gauge: GaugeRef
    
    init(_ gauge: GaugeRef) {
        self.gauge = gauge
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Location", systemImage: "map.fill")
                .font(.headline)

            Map(position: $mapCameraPosition) {
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

            HStack(spacing: 16) {
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
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}
