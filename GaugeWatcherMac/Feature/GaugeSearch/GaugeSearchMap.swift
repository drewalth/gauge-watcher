//
//  GaugeSearchMap.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import ComposableArchitecture
import MapKit
import SharedFeatures
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
            }.searchable(text: .constant(""), prompt: "Search")
    }
}

// MARK: - ClusteredMapView

struct ClusteredMapView: NSViewRepresentable {

    // MARK: Internal

    let gauges: [GaugeRef]
    let store: StoreOf<GaugeSearchFeature>
    let userLocation: CurrentLocation?
    let shouldRecenter: Bool

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isPitchEnabled = false

        // Register annotation views for clustering
        mapView.register(
            GaugeAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(
            GaugeClusterAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)

        // Set initial region - user location if available, otherwise default to US center
        let initialRegion: MKCoordinateRegion
        if let location = userLocation {
            initialRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                latitudinalMeters: 150_000,
                longitudinalMeters: 150_000)
        } else {
            // Default to center of continental US
            initialRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
                latitudinalMeters: 5_000_000,
                longitudinalMeters: 5_000_000)
        }
        mapView.setRegion(initialRegion, animated: false)

        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.store = store
        updateAnnotations(mapView: mapView, gauges: gauges)

        // Handle recenter request
        if shouldRecenter, let location = userLocation {
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                latitudinalMeters: 150_000,
                longitudinalMeters: 150_000)
            mapView.setRegion(region, animated: true)
            context.coordinator.recenterCompleted()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    // MARK: Private

    private func updateAnnotations(mapView: MKMapView, gauges: [GaugeRef]) {
        let existingAnnotations = mapView.annotations.compactMap { $0 as? GaugeAnnotation }
        let existingIDs = Set(existingAnnotations.map { $0.gaugeRef.id })
        let newIDs = Set(gauges.map { $0.id })

        // Remove annotations that are no longer in the list
        let toRemove = existingAnnotations.filter { !newIDs.contains($0.gaugeRef.id) }
        mapView.removeAnnotations(toRemove)

        // Add new annotations
        let toAdd = gauges.filter { !existingIDs.contains($0.id) }.map { GaugeAnnotation(gaugeRef: $0) }
        mapView.addAnnotations(toAdd)
    }
}

// MARK: ClusteredMapView.Coordinator

extension ClusteredMapView {
    final class Coordinator: NSObject, MKMapViewDelegate {

        // MARK: Lifecycle

        init(store: StoreOf<GaugeSearchFeature>) {
            self.store = store
        }

        // MARK: Internal

        var store: StoreOf<GaugeSearchFeature>

        func recenterCompleted() {
            store.send(.recenterCompleted)
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Let the system handle user location annotation
            if annotation is MKUserLocation {
                return nil
            }

            guard annotation is GaugeAnnotation else {
                return nil
            }

            guard
                let annotationView = mapView.dequeueReusableAnnotationView(
                    withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier,
                    for: annotation) as? MKMarkerAnnotationView
            else {
                return nil
            }

            annotationView.clusteringIdentifier = "gauge"
            return annotationView
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // Handle cluster annotation selection
            if let cluster = view.annotation as? MKClusterAnnotation {
                let annotations = cluster.memberAnnotations
                guard !annotations.isEmpty else { return }

                // Calculate bounds of all annotations to zoom in
                var minLat = Double.greatestFiniteMagnitude
                var maxLat = -Double.greatestFiniteMagnitude
                var minLon = Double.greatestFiniteMagnitude
                var maxLon = -Double.greatestFiniteMagnitude

                for annotation in annotations {
                    let lat = annotation.coordinate.latitude
                    let lon = annotation.coordinate.longitude
                    minLat = min(minLat, lat)
                    maxLat = max(maxLat, lat)
                    minLon = min(minLon, lon)
                    maxLon = max(maxLon, lon)
                }

                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2)

                let span = MKCoordinateSpan(
                    latitudeDelta: (maxLat - minLat) * 1.5,
                    longitudeDelta: (maxLon - minLon) * 1.5)

                let region = MKCoordinateRegion(center: center, span: span)
                mapView.setRegion(region, animated: true)
                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }

            // Handle individual gauge selection
            guard let gaugeAnnotation = view.annotation as? GaugeAnnotation else {
                return
            }

            store.send(.goToGaugeDetail(gaugeAnnotation.gaugeRef.id))
            mapView.deselectAnnotation(view.annotation, animated: true)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated _: Bool) {
            let region = mapView.region

            // Only report if region changed significantly (avoid duplicate reports)
            if let last = lastReportedRegion {
                let centerDiff = abs(region.center.latitude - last.center.latitude) +
                    abs(region.center.longitude - last.center.longitude)
                let spanDiff = abs(region.span.latitudeDelta - last.span.latitudeDelta) +
                    abs(region.span.longitudeDelta - last.span.longitudeDelta)

                // Only report if moved/zoomed significantly (>5% change)
                if
                    centerDiff < region.span.latitudeDelta * 0.05,
                    spanDiff < region.span.latitudeDelta * 0.05 {
                    return
                }
            }

            lastReportedRegion = region
            store.send(.mapRegionChanged(region))
        }

        // MARK: Private

        private var lastReportedRegion: MKCoordinateRegion?
    }
}

// MARK: - GaugeAnnotation

final class GaugeAnnotation: NSObject, MKAnnotation {

    // MARK: Lifecycle

    init(gaugeRef: GaugeRef) {
        self.gaugeRef = gaugeRef
        super.init()
    }

    // MARK: Internal

    let gaugeRef: GaugeRef

    var coordinate: CLLocationCoordinate2D {
        gaugeRef.location.coordinate
    }

    var title: String? {
        gaugeRef.name
    }
}

// MARK: - GaugeAnnotationView

final class GaugeAnnotationView: MKMarkerAnnotationView {

    // MARK: Lifecycle

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        clusteringIdentifier = "gauge"
        markerTintColor = .systemBlue
        glyphImage = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: nil)
        displayPriority = .defaultHigh
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    override func prepareForReuse() {
        super.prepareForReuse()
        clusteringIdentifier = "gauge"
    }
}

// MARK: - GaugeClusterAnnotationView

final class GaugeClusterAnnotationView: MKMarkerAnnotationView {

    // MARK: Lifecycle

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        markerTintColor = .systemBlue
        displayPriority = .defaultHigh
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    override func prepareForDisplay() {
        super.prepareForDisplay()

        guard let cluster = annotation as? MKClusterAnnotation else { return }

        let count = cluster.memberAnnotations.count
        glyphText = "\(count)"
    }
}

// MARK: - Preview

#Preview {
    GaugeSearchMap(store: Store(initialState: GaugeSearchFeature.State()) {
        GaugeSearchFeature()
    })
}
