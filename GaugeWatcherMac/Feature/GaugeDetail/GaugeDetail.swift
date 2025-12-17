//
//  GaugeDetail.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import GaugeSources
import MapKit
import SharedFeatures
import SwiftUI

// MARK: - GaugeDetail

struct GaugeDetail: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                backgroundGradient
            }
            .task {
                store.send(.load)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    toolbarContent
                }
            }
    }

    // MARK: Private

    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var showingLocationPopover = false

    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .windowBackgroundColor).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var content: some View {
        switch store.gauge {
        case .initial, .loading:
            loadingView
        case .loaded(let gauge), .reloading(let gauge):
            gaugeContent(gauge)
        case .error(let error):
            errorView(error)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading gauge data...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var toolbarContent: some View {
        if let gauge = store.gauge.unwrap() {
            // Favorite toggle
            Button {
                store.send(.toggleFavorite)
            } label: {
                Label(
                    gauge.favorite ? "Remove Favorite" : "Add Favorite",
                    systemImage: gauge.favorite ? "star.fill" : "star")
            }
            .help(gauge.favorite ? "Remove from favorites" : "Add to favorites")

            // Open source
            if gauge.sourceURL != nil {
                Button {
                    store.send(.openSource)
                } label: {
                    Label("View Source", systemImage: "safari")
                }
                .help("Open gauge source website")
            }
        }
    }

    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Unable to Load Gauge", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Try Again") {
                store.send(.load)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func gaugeContent(_ gauge: GaugeRef) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero header
                heroHeader(gauge)

                // Latest reading section
                LatestGaugeReading(store: store)

                // Flow chart section
                GaugeReadingChart(store: store)

                // Forecast section
                GaugeFlowForecast(store: store)

                // Location & Info section
                HStack(alignment: .top, spacing: 16) {
                    locationCard(gauge)
                    infoCard(gauge)
                }

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func heroHeader(_ gauge: GaugeRef) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                // Source badge
                HStack(spacing: 8) {
                    sourceBadge(gauge.source)

                    if gauge.favorite {
                        Label("Favorite", systemImage: "star.fill")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(.yellow.opacity(0.2))
                            }
                            .foregroundStyle(.yellow)
                    }

                    statusBadge(gauge)
                }

                // Gauge name
                Text(gauge.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                // Location info
                HStack(spacing: 16) {
                    Label(gauge.state, systemImage: "mappin.circle.fill")
                    Label(gauge.country, systemImage: "globe.americas.fill")
                    Label("Site \(gauge.siteID)", systemImage: "number.circle.fill")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func sourceBadge(_ source: GaugeSource) -> some View {
        let (color, icon) = sourceStyle(for: source)

        Label(source.rawValue, systemImage: icon)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(color.opacity(0.15))
            }
            .foregroundStyle(color)
    }

    @ViewBuilder
    private func statusBadge(_ gauge: GaugeRef) -> some View {
        let isStale = gauge.isStale()

        Label(isStale ? "Stale" : "Current", systemImage: isStale ? "clock.badge.exclamationmark" : "checkmark.circle")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(isStale ? .orange.opacity(0.15) : .green.opacity(0.15))
            }
            .foregroundStyle(isStale ? .orange : .green)
    }

    @ViewBuilder
    private func locationCard(_ gauge: GaugeRef) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Location", systemImage: "map.fill")
                    .font(.headline)

                Spacer()

                Button {
                    showingLocationPopover.toggle()
                } label: {
                    Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingLocationPopover, arrowEdge: .trailing) {
                    expandedMapView(gauge)
                }
            }

            // Mini map
            Map(position: $mapCameraPosition) {
                Marker(gauge.name, coordinate: CLLocationCoordinate2D(
                        latitude: gauge.latitude,
                        longitude: gauge.longitude))
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear {
                mapCameraPosition = .region(MKCoordinateRegion(
                                                center: CLLocationCoordinate2D(latitude: gauge.latitude, longitude: gauge.longitude),
                                                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)))
            }

            // Coordinates
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latitude")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(gauge.latitude, format: .number.precision(.fractionLength(4)))
                        .font(.system(.caption, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Longitude")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(gauge.longitude, format: .number.precision(.fractionLength(4)))
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func expandedMapView(_ gauge: GaugeRef) -> some View {
        VStack(spacing: 0) {
            Map(position: $mapCameraPosition) {
                Marker(gauge.name, coordinate: CLLocationCoordinate2D(
                        latitude: gauge.latitude,
                        longitude: gauge.longitude))
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .all))
            .mapControls {
                MapCompass()
                MapScaleView()
                MapZoomStepper()
            }
        }
        .frame(width: 500, height: 400)
    }

    @ViewBuilder
    private func infoCard(_ gauge: GaugeRef) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Details", systemImage: "info.circle.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                infoRow(label: "Zone", value: gauge.zone.isEmpty ? "—" : gauge.zone, icon: "square.grid.2x2")
                infoRow(label: "Primary Metric", value: gauge.metric.rawValue, icon: "ruler")
                infoRow(label: "Primary Gauge", value: gauge.primary ? "Yes" : "No", icon: "star.circle")
                infoRow(
                    label: "Last Updated",
                    value: gauge.updatedAt.formatted(date: .abbreviated, time: .shortened),
                    icon: "clock")
                infoRow(
                    label: "Added",
                    value: gauge.createdAt.formatted(date: .abbreviated, time: .omitted),
                    icon: "calendar")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
    }

    private func sourceStyle(for source: GaugeSource) -> (Color, String) {
        switch source {
        case .usgs:
            return (.blue, "building.columns.fill")
        case .environmentCanada:
            return (.red, "leaf.fill")
        case .dwr:
            return (.orange, "mountain.2.fill")
        case .lawa:
            return (.teal, "water.waves")
        }
    }

}

// MARK: - Preview

#Preview {
    NavigationStack {
        GaugeDetail(store: Store(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        })
    }
    .frame(width: 800, height: 900)
}
