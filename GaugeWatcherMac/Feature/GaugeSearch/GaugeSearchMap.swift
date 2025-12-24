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
            shouldRecenter: store.shouldRecenterMap,
            shouldZoomToResults: store.shouldZoomToResults,
            shouldFitAllPins: store.shouldFitAllPins,
            shouldCenterOnSelection: store.shouldCenterOnSelection,
            selectedGaugeID: store.inspectorDetail?.gaugeID)
            .overlay(alignment: .bottomTrailing) {
                if store.searchMode == .filtered, store.filterOptions.hasActiveFilters {
                    FilterIndicatorBanner(onClear: { store.send(.clearFilters) })
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .padding()
                }
            }
            .animation(.snappy, value: store.filterOptions.hasActiveFilters)
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        // Fit All Gauges only makes sense in filtered mode where results are user-driven
                        if store.searchMode == .filtered {
                            Button {
                                store.send(.fitAllPins)
                            } label: {
                                Label("Fit All Gauges", systemImage: "arrow.up.left.and.arrow.down.right")
                            }
                            .disabled(store.results.unwrap()?.isEmpty ?? true)

                            Divider()
                        }

                        Button {
                            store.send(.recenterOnUserLocation)
                        } label: {
                            Label("Reset View", systemImage: "arrow.counterclockwise")
                        }
                        .disabled(store.currentLocation == nil)

                        if store.inspectorDetail != nil {
                            Divider()

                            Button {
                                store.send(.centerOnSelectedGauge)
                            } label: {
                                Label("Center on Selection", systemImage: "scope")
                            }
                        }
                    } label: {
                        Label("Map Options", systemImage: "map")
                    }
                }
            }
    }
}

// MARK: - ClusteredMapView

struct ClusteredMapView: NSViewRepresentable {

    // MARK: Internal

    let gauges: [GaugeRef]
    let store: StoreOf<GaugeSearchFeature>
    let userLocation: CurrentLocation?
    let shouldRecenter: Bool
    let shouldZoomToResults: Bool
    let shouldFitAllPins: Bool
    let shouldCenterOnSelection: Bool
    let selectedGaugeID: Int?

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

        // Store user location in coordinator for initial zoom after map loads
        context.coordinator.pendingUserLocation = userLocation

        // Always start with default US center - we'll zoom to user location in mapViewDidFinishLoadingMap
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
            latitudinalMeters: 5_000_000,
            longitudinalMeters: 5_000_000)
        mapView.setRegion(initialRegion, animated: false)

        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.store = store
        context.coordinator.pendingUserLocation = userLocation
        updateAnnotations(mapView: mapView, gauges: gauges)

        // Handle initial zoom if map has loaded and we have location but haven't zoomed yet
        if
            context.coordinator.mapDidFinishLoading,
            !context.coordinator.hasPerformedInitialZoom,
            let location = userLocation {
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                latitudinalMeters: 150_000,
                longitudinalMeters: 150_000)
            mapView.setRegion(region, animated: true)
            context.coordinator.hasPerformedInitialZoom = true
        }

        // Handle recenter request
        if shouldRecenter, let location = userLocation {
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                latitudinalMeters: 150_000,
                longitudinalMeters: 150_000)
            mapView.setRegion(region, animated: true)
            context.coordinator.recenterCompleted()
        }

        // Handle zoom to results (for filtered search)
        // Only zoom when results are fully loaded (not reloading with stale data)
        // IMPORTANT: Use fresh data from store.results, not the potentially stale `gauges` parameter
        // The `gauges` parameter can lag behind store.results during SwiftUI's update cycle
        if shouldZoomToResults, case .loaded(let freshResults) = store.results, !freshResults.isEmpty {
            zoomToFitGauges(mapView: mapView, gauges: freshResults)
            context.coordinator.zoomToResultsCompleted()
        }

        // Handle fit all pins
        if shouldFitAllPins, case .loaded(let freshResults) = store.results, !freshResults.isEmpty {
            zoomToFitGauges(mapView: mapView, gauges: freshResults)
            context.coordinator.fitAllPinsCompleted()
        }

        // Handle center on selection
        if shouldCenterOnSelection,
           let gaugeID = selectedGaugeID,
           let gauge = gauges.first(where: { $0.id == gaugeID }) {
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: gauge.latitude, longitude: gauge.longitude),
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000)
            mapView.setRegion(region, animated: true)
            context.coordinator.centerOnSelectionCompleted()
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

    private func zoomToFitGauges(mapView: MKMapView, gauges: [GaugeRef]) {
        guard !gauges.isEmpty else { return }

        // Calculate bounding box of all gauges
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude

        for gauge in gauges {
            minLat = min(minLat, gauge.latitude)
            maxLat = max(maxLat, gauge.latitude)
            minLon = min(minLon, gauge.longitude)
            maxLon = max(maxLon, gauge.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2)

        // Add padding to the span (20% on each side)
        let latDelta = max((maxLat - minLat) * 1.4, 0.1) // Minimum span for single point
        let lonDelta = max((maxLon - minLon) * 1.4, 0.1)

        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        let region = MKCoordinateRegion(center: center, span: span)

        mapView.setRegion(region, animated: true)
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
        var hasPerformedInitialZoom = false
        var mapDidFinishLoading = false
        var pendingUserLocation: CurrentLocation?

        func recenterCompleted() {
            store.send(.recenterCompleted)
        }

        func zoomToResultsCompleted() {
            store.send(.zoomToResultsCompleted)
        }

        func fitAllPinsCompleted() {
            store.send(.fitAllPinsCompleted)
        }

        func centerOnSelectionCompleted() {
            store.send(.centerOnSelectionCompleted)
        }

        // MARK: - MKMapViewDelegate

        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            mapDidFinishLoading = true

            // Perform initial zoom to user location if available and not already done
            guard !hasPerformedInitialZoom, let location = pendingUserLocation else { return }

            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                latitudinalMeters: 150_000,
                longitudinalMeters: 150_000)
            mapView.setRegion(region, animated: true)
            hasPerformedInitialZoom = true
        }

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

            // Use inspector-based selection on macOS instead of navigation push
            store.send(.selectGaugeForInspector(gaugeAnnotation.gaugeRef.id))
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

final class GaugeAnnotationView: MKAnnotationView {

    // MARK: Lifecycle

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        clusteringIdentifier = "gauge"
        displayPriority = .defaultHigh
        collisionMode = .circle

        frame = CGRect(x: 0, y: 0, width: Self.size, height: Self.size)
        centerOffset = CGPoint(x: 0, y: -Self.size / 2)

        setupView()
        setupTrackingArea()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    static let size: CGFloat = 32

    override func prepareForReuse() {
        super.prepareForReuse()
        clusteringIdentifier = "gauge"
        dismissPopover()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                containerView.animator().alphaValue = selected ? 0.85 : 1.0
                let scale = selected ? 1.15 : 1.0
                containerView.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
            }
        } else {
            containerView.alphaValue = selected ? 0.85 : 1.0
            let scale = selected ? 1.15 : 1.0
            containerView.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)

        // Verify the mouse is actually over this view and not obscured by another view (e.g., sidebar)
        guard let window else { return }
        let windowLocation = event.locationInWindow
        guard let hitView = window.contentView?.hitTest(windowLocation) else { return }

        // Only show popover if hit test returns this view or one of its subviews
        var view: NSView? = hitView
        while let current = view {
            if current === self {
                showPopover()
                applyHoverEffect(true)
                return
            }
            view = current.superview
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        dismissPopover()
        applyHoverEffect(false)
    }

    // MARK: Private

    private static let hoverScale: CGFloat = 1.08

    private let containerView = NSView()
    private var popover: NSPopover?
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false

        // Container with shadow
        containerView.frame = bounds
        containerView.wantsLayer = true
        containerView.layer?.masksToBounds = false
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = 0.25
        containerView.layer?.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer?.shadowRadius = 4
        addSubview(containerView)

        // Gradient background circle
        let backgroundLayer = CAGradientLayer()
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = Self.size / 2
        backgroundLayer.colors = [
            NSColor(calibratedRed: 0.2, green: 0.5, blue: 0.85, alpha: 1.0).cgColor,
            NSColor(calibratedRed: 0.15, green: 0.35, blue: 0.7, alpha: 1.0).cgColor
        ]
        backgroundLayer.startPoint = CGPoint(x: 0.5, y: 0)
        backgroundLayer.endPoint = CGPoint(x: 0.5, y: 1)
        containerView.layer?.addSublayer(backgroundLayer)

        // Inner highlight ring
        let highlightLayer = CALayer()
        highlightLayer.frame = bounds.insetBy(dx: 2, dy: 2)
        highlightLayer.cornerRadius = (Self.size - 4) / 2
        highlightLayer.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        highlightLayer.borderWidth = 1
        containerView.layer?.addSublayer(highlightLayer)

        // Water drop icon
        let iconSize: CGFloat = 16
        let iconLayer = CALayer()
        iconLayer.frame = CGRect(
            x: (Self.size - iconSize) / 2,
            y: (Self.size - iconSize) / 2,
            width: iconSize,
            height: iconSize)

        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
        if
            let image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
            let tintedImage = image.tinted(with: .white)
            iconLayer.contents = tintedImage
            iconLayer.contentsGravity = .resizeAspect
        }
        containerView.layer?.addSublayer(iconLayer)

        // Outer ring for depth
        let outerRing = CALayer()
        outerRing.frame = bounds
        outerRing.cornerRadius = Self.size / 2
        outerRing.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        outerRing.borderWidth = 1.5
        containerView.layer?.addSublayer(outerRing)
    }

    private func setupTrackingArea() {
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    private func applyHoverEffect(_ hovering: Bool) {
        isHovering = hovering

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let scale = hovering ? Self.hoverScale : 1.0
            containerView.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))

            // Enhance shadow on hover
            containerView.layer?.shadowOpacity = hovering ? 0.4 : 0.25
            containerView.layer?.shadowRadius = hovering ? 6 : 4
        }
    }

    private func showPopover() {
        guard popover == nil else { return }
        guard let gaugeAnnotation = annotation as? GaugeAnnotation else { return }

        let contentView = GaugePopoverView(gaugeName: gaugeAnnotation.gaugeRef.name)
        let hostingController = NSHostingController(rootView: contentView)

        let newPopover = NSPopover()
        newPopover.contentViewController = hostingController
        newPopover.behavior = .semitransient
        newPopover.animates = true

        // Position popover above the marker
        // Convert to window coordinates to avoid MKMapView transform issues
        if let contentView = window?.contentView {
            let windowRect = convert(containerView.bounds, to: contentView)
            newPopover.show(relativeTo: windowRect, of: contentView, preferredEdge: .maxY)
        } else {
            newPopover.show(relativeTo: containerView.bounds, of: containerView, preferredEdge: .maxY)
        }
        popover = newPopover
    }

    private func dismissPopover() {
        popover?.close()
        popover = nil
    }
}

// MARK: - GaugePopoverView

private struct GaugePopoverView: View {
    let gaugeName: String

    var body: some View {
        Text(gaugeName)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .fixedSize()
    }
}

// MARK: - GaugeClusterAnnotationView

final class GaugeClusterAnnotationView: MKAnnotationView {

    // MARK: Lifecycle

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        displayPriority = .defaultHigh
        collisionMode = .circle

        setupView()
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
        updateCount(count)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                let scale = selected ? 1.1 : 1.0
                containerView.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
            }
        } else {
            let scale = selected ? 1.1 : 1.0
            containerView.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
    }

    // MARK: Private

    private static let baseSize: CGFloat = 40

    private let containerView = NSView()
    private let countLabel = NSTextField(labelWithString: "")
    private var backgroundLayer: CAGradientLayer?
    private var glowLayer: CALayer?
    private var outerRingLayer: CALayer?

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false

        let size = Self.baseSize
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        centerOffset = CGPoint(x: 0, y: -size / 2)

        // Container with shadow
        containerView.frame = bounds
        containerView.wantsLayer = true
        containerView.layer?.masksToBounds = false
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = 0.3
        containerView.layer?.shadowOffset = CGSize(width: 0, height: 3)
        containerView.layer?.shadowRadius = 6
        addSubview(containerView)

        // Gradient background
        let bgLayer = CAGradientLayer()
        bgLayer.frame = bounds
        bgLayer.cornerRadius = size / 2
        bgLayer.colors = [
            NSColor(calibratedRed: 0.1, green: 0.3, blue: 0.6, alpha: 1.0).cgColor,
            NSColor(calibratedRed: 0.08, green: 0.2, blue: 0.45, alpha: 1.0).cgColor
        ]
        bgLayer.startPoint = CGPoint(x: 0.5, y: 0)
        bgLayer.endPoint = CGPoint(x: 0.5, y: 1)
        containerView.layer?.addSublayer(bgLayer)
        backgroundLayer = bgLayer

        // Inner glow
        let glow = CALayer()
        glow.frame = bounds.insetBy(dx: 3, dy: 3)
        glow.cornerRadius = (size - 6) / 2
        glow.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        glow.borderWidth = 1.5
        containerView.layer?.addSublayer(glow)
        glowLayer = glow

        // Count label
        countLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        countLabel.textColor = .white
        countLabel.alignment = .center
        countLabel.backgroundColor = .clear
        countLabel.isBezeled = false
        countLabel.isEditable = false
        countLabel.sizeToFit()
        containerView.addSubview(countLabel)

        // Outer ring
        let outerRing = CALayer()
        outerRing.frame = bounds
        outerRing.cornerRadius = size / 2
        outerRing.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        outerRing.borderWidth = 2
        containerView.layer?.addSublayer(outerRing)
        outerRingLayer = outerRing
    }

    private func updateCount(_ count: Int) {
        let displayText = count > 999 ? "999+" : "\(count)"
        countLabel.stringValue = displayText

        // Adjust size based on count magnitude
        let size: CGFloat
        let fontSize: CGFloat
        if count > 99 {
            size = Self.baseSize + 8
            fontSize = 12
        } else if count > 9 {
            size = Self.baseSize + 4
            fontSize = 13
        } else {
            size = Self.baseSize
            fontSize = 14
        }

        frame = CGRect(x: 0, y: 0, width: size, height: size)
        centerOffset = CGPoint(x: 0, y: -size / 2)
        containerView.frame = bounds

        // Update each layer with its correct geometry
        backgroundLayer?.frame = bounds
        backgroundLayer?.cornerRadius = size / 2

        glowLayer?.frame = bounds.insetBy(dx: 3, dy: 3)
        glowLayer?.cornerRadius = (size - 6) / 2

        outerRingLayer?.frame = bounds
        outerRingLayer?.cornerRadius = size / 2

        countLabel.font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        countLabel.sizeToFit()
        countLabel.frame = CGRect(
            x: (size - countLabel.frame.width) / 2,
            y: (size - countLabel.frame.height) / 2,
            width: countLabel.frame.width,
            height: countLabel.frame.height)
    }
}

// MARK: - NSImage Tinting Extension

extension NSImage {
    fileprivate func tinted(with color: NSColor) -> NSImage {
        let newImage = NSImage(size: size, flipped: false) { rect in
            color.set()
            rect.fill()
            self.draw(in: rect, from: rect, operation: .destinationIn, fraction: 1.0)
            return true
        }
        newImage.isTemplate = false
        return newImage
    }
}

// MARK: - Preview

#Preview {
    GaugeSearchMap(store: Store(initialState: GaugeSearchFeature.State()) {
        GaugeSearchFeature()
    })
}
