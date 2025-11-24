//
//  GaugeSearchMap.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import SwiftUI
import MapKit
import Loadable

struct GaugeSearchMap: View {
    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
       Map(position: $position, interactionModes: .all) {
            ForEach(store.results.unwrap() ?? [], id: \.id) { gauge in
                Annotation(gauge.name, coordinate: gauge.location.coordinate) {
                    GaugeMapMarker(store: store, gauge: gauge)
                }
                .annotationTitles(.hidden)
            }
            UserAnnotation()
        }.ignoresSafeArea(.all)
    }


    @State private var position: MapCameraPosition = .region(.init(
                                                                center: .init(latitude: 39.8283, longitude: -98.5795),
                                                                span: .init(latitudeDelta: 100, longitudeDelta: 100)))

    private let defaultSpan = MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)

    private func setPosition(_: CurrentLocation?) {
        guard let currentLocation = store.currentLocation else { return }
        withAnimation {
            position = .region(.init(
                                center: .init(
                                    latitude: currentLocation.latitude,
                                    longitude: currentLocation.longitude),
                                span: defaultSpan))
        }
    }
}
