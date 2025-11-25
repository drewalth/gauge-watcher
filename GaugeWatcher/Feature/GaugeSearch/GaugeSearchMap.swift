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

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        Map(position: $viewModel.position, interactionModes: [.pan, .zoom, .rotate]) {
            ForEach(store.results.unwrap() ?? [], id: \.id) { gauge in
                Annotation(gauge.name, coordinate: gauge.location.coordinate) {
                    GaugeMapMarker(store: store, gauge: gauge)
                }
                .annotationTitles(.hidden)
            }
            UserAnnotation()
        }.ignoresSafeArea(.all)
        .onChange(of: store.currentLocation) { prev, next in
            if prev != next {
                viewModel.setPosition(next)
            }
        }
        .onAppear {
            viewModel.handleStateChange(store.queryOptions.state)
        }
        .trackView("GaugeSearchMap")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.toggleMode)
                } label: {
                    Label("Mode", systemImage: store.mode == .list ? "map": "list.bullet")
                        .labelStyle(.iconOnly)
                }
            }
        }
    }

    // MARK: Private

    @State private var viewModel = ViewModel()
}

// MARK: GaugeSearchMap.ViewModel

extension GaugeSearchMap {
    /// Note: We break the state mgmt paradigm here intentionally.
    /// These values are not placed in the TCA reducer because they will change frequently
    /// and we don't want to overload the system.
    /// TCA docs suggest things that update frequently probably shouldn't be placed in state/effect. (needs verify)
    @Observable
    final class ViewModel {

        // MARK: Internal

        var position: MapCameraPosition = .region(.init(
                                                    center: .init(latitude: 39.8283, longitude: -98.5795),
                                                    span: .init(latitudeDelta: 100, longitudeDelta: 100)))

        func setPosition(_ currentLocation: CurrentLocation?) {
            guard let currentLocation else { return }
            withAnimation {
                position = .region(.init(
                                    center: .init(
                                        latitude: currentLocation.latitude,
                                        longitude: currentLocation.longitude),
                                    span: defaultSpan))
            }
        }

        func handleStateChange(_ state: String?) {
            Task {
                do {
                    guard
                        let state,
                        let stateValue = StateValue(rawValue: state)
                    else {
                        return
                    }
                    try Task.checkCancellation()
                    let address = if StatesProvinces.CanadianProvince.allCases.map({ $0.value }).contains(stateValue) {
                        "\(stateValue.name), Canada"
                    } else if StatesProvinces.NewZealandRegion.allCases.map({ $0.value }).contains(stateValue) {
                        "\(stateValue.name), New Zealand"
                    } else {
                        "\(stateValue.name), United States"
                    }

                    guard let coordinates = try await CLGeocoder().geocodeAddressString(address).first?.location?.coordinate else {
                        return
                    }

                    DispatchQueue.main.async {
                        self.position = .region(.init(
                                                    center: .init(
                                                        latitude: coordinates.latitude,
                                                        longitude: coordinates.longitude),
                                                    span: self.defaultSpan))
                    }

                } catch {
                    print(error)
                }
            }
        }

        // MARK: Private

        private let defaultSpan = MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)

    }
}
