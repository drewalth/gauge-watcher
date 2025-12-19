//
//  GaugeDetailInspector.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/19/25.
//

import GaugeSources
import MapKit
import SharedFeatures
import SwiftUI

// MARK: - GaugeDetailInspector

/// Inspector-optimized gauge detail view for macOS.
/// Designed for the narrower inspector panel width with vertical layout.
struct GaugeDetailInspector: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeDetailFeature>
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color(nsColor: .controlBackgroundColor)
        }
    }

    // MARK: Private

    @State private var mapCameraPosition: MapCameraPosition = .automatic

    @ViewBuilder
    private var inspectorHeader: some View {
        HStack(spacing: 12) {
            Text("Gauge Details")
                .font(.headline)

            Spacer()

            if let gauge = store.gauge.unwrap() {
                Button {
                    store.send(.toggleFavorite)
                } label: {
                    Image(systemName: gauge.favorite ? "star.fill" : "star")
                        .foregroundStyle(gauge.favorite ? .yellow : .secondary)
                }
                .buttonStyle(.borderless)
                .help(gauge.favorite ? "Remove from favorites" : "Add to favorites")

                if gauge.sourceURL != nil {
                    Button {
                        store.send(.openSource)
                    } label: {
                        Image(systemName: "safari")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Open gauge source website")
                }
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Close inspector")
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
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
                .scaleEffect(1.2)
            Text("Loading gauge...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            VStack(alignment: .leading, spacing: 20) {
                // Header with close affordance
                heroHeader(gauge)

                // Latest reading
                LatestGaugeReading(store: store)

                // Flow chart
                GaugeReadingChart(store: store)

                // Forecast
                GaugeFlowForecast(store: store)

                // Location map (compact)
                locationSection(gauge)

                // Info details
                infoSection(gauge)

                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .scrollIndicators(.automatic)
    }

    @ViewBuilder
    private func heroHeader(_ gauge: GaugeRef) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Badges row
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

                Spacer()
            }

            // Gauge name
            Text(gauge.name)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Location info
            VStack(alignment: .leading, spacing: 4) {
                Label(gauge.state, systemImage: "mappin.circle.fill")
                Label("Site \(gauge.siteID)", systemImage: "number.circle.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func sourceBadge(_ source: GaugeSource) -> some View {
        let (color, icon) = sourceStyle(for: source)

        Label(source.rawValue, systemImage: icon)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(color.opacity(0.15))
            }
            .foregroundStyle(color)
    }

    @ViewBuilder
    private func statusBadge(_ gauge: GaugeRef) -> some View {
        let isStale = gauge.isStale()

        Label(
            isStale ? "Stale" : "Current",
            systemImage: isStale ? "clock.badge.exclamationmark" : "checkmark.circle")
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
    private func locationSection(_ gauge: GaugeRef) -> some View {
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

    @ViewBuilder
    private func infoSection(_ gauge: GaugeRef) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Details", systemImage: "info.circle.fill")
                .font(.headline)

            VStack(spacing: 12) {
                infoRow(label: "Zone", value: gauge.zone.isEmpty ? "—" : gauge.zone)
                infoRow(label: "Primary Metric", value: gauge.metric.rawValue)
                infoRow(label: "Last Updated", value: gauge.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
    }

    private func sourceStyle(for source: GaugeSource) -> (Color, String) {
        switch source {
        case .usgs:
            (.blue, "building.columns.fill")
        case .environmentCanada:
            (.red, "leaf.fill")
        case .dwr:
            (.orange, "mountain.2.fill")
        case .lawa:
            (.teal, "water.waves")
        }
    }
}

// MARK: - Preview

#Preview {
    GaugeDetailInspector(
        store: Store(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        },
        onClose: { })
        .frame(width: 400, height: 800)
}

