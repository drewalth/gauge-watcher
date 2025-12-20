//
//  GaugeDetailInspector.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/19/25.
//

import AccessibleUI
import AppTelemetry
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
        }.sheet(isPresented: $store.infoSheetPresented.sending(\.setInfoSheetPresented)) {
            GaugeDetailInfoSheet(gauge: store.gauge.unwrap(), onClose: {
                store.send(.setInfoSheetPresented(false))
            })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color(nsColor: .controlBackgroundColor)
        }.trackView("GaugeDetailInspector", {
            if let gauge = store.gauge.unwrap() {
                return [
                    "Gauge": gauge.name,
                    "GaugeID": gauge.id,
                    "GaugeSource": gauge.source.rawValue,
                    "GaugeState": gauge.state,
                    "GaugeSiteID": gauge.siteID,
                    "GaugeLatitude": gauge.latitude,
                    "GaugeLongitude": gauge.longitude,
                    "GaugeUpdatedAt": gauge.updatedAt.formatted(date: .abbreviated, time: .shortened),
                    "GaugeZone": gauge.zone,
                    "GaugeMetric": gauge.metric.rawValue
                ]
            }
            return [:]
        }())
    }

    // MARK: Private

    @ViewBuilder
    private var inspectorHeader: some View {
        HStack(spacing: 12) {
            Text("Gauge Details")
                .font(.headline)

            Spacer()

            // Always show buttons to prevent layout shift, disable when not ready
            let gauge = store.gauge.unwrap()
            let isLoaded = gauge != nil

            Button {
                store.send(.toggleFavorite)
            } label: {
                Image(systemName: gauge?.favorite == true ? "star.fill" : "star")
                    .foregroundStyle(gauge?.favorite == true ? .yellow : .secondary)
            }
            .buttonStyle(.borderless)
            .help(gauge?.favorite == true ? "Remove from favorites" : "Add to favorites")
            .disabled(!isLoaded)
            .opacity(isLoaded ? 1 : 0.4)
            .accessibleButton(label: gauge?.favorite == true ? "Remove from favorites" : "Add to favorites")

            Button {
                store.send(.setInfoSheetPresented(true))
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)

            GaugeSourceButton(store: store)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Close inspector")
            .keyboardShortcut(.escape, modifiers: [])
            .accessibleButton(label: "Close inspector")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        switch store.gauge {
        case .initial, .loading:
            skeletonContent
        case .loaded(let gauge), .reloading(let gauge):
            gaugeContent(gauge)
        case .error(let error):
            errorView(error)
        }
    }

    private var skeletonContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header skeleton
                skeletonHeader

                // Use actual components - they handle their own loading states
                LatestGaugeReading(store: store)
                GaugeReadingChart(store: store)

                // Forecast skeleton (matches GaugeFlowForecast layout)
                skeletonForecast

                // Location skeleton
                skeletonLocation

                // Info skeleton
                skeletonInfo

                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .scrollIndicators(.automatic)
    }

    private var skeletonHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                skeletonPill(width: 80)
                skeletonPill(width: 60)
            }
            skeletonRect(height: 24)
            VStack(alignment: .leading, spacing: 4) {
                skeletonRect(width: 120, height: 14)
                skeletonRect(width: 100, height: 14)
            }
        }
    }

    private var skeletonForecast: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                skeletonRect(width: 100, height: 18)
                Spacer()
            }
            skeletonRect(height: 80)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private var skeletonLocation: some View {
        VStack(alignment: .leading, spacing: 10) {
            skeletonRect(width: 80, height: 18)
            skeletonRect(height: 140)
            HStack(spacing: 16) {
                skeletonRect(width: 80, height: 30)
                skeletonRect(width: 80, height: 30)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private var skeletonInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            skeletonRect(width: 60, height: 18)
            VStack(spacing: 12) {
                infoRowSkeleton
                infoRowSkeleton
                infoRowSkeleton
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private var infoRowSkeleton: some View {
        HStack {
            skeletonRect(width: 80, height: 16)
            Spacer()
            skeletonRect(width: 100, height: 16)
        }
    }

    private var reloadingOverlay: some View {
        Color.black.opacity(0.1)
            .ignoresSafeArea()
            .overlay {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
    }

    private func skeletonRect(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.primary.opacity(0.08))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .shimmering()
    }

    private func skeletonPill(width: CGFloat) -> some View {
        Capsule()
            .fill(.primary.opacity(0.08))
            .frame(width: width, height: 22)
            .shimmering()
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
            .accessibleButton(label: "Try Again")
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
                GaugeLocationTile(gauge, store: store)

                // Info details
                infoSection(gauge)
                    .modifier(OutlinedTileModifier())

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
    private func infoSection(_ gauge: GaugeRef) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Details", systemImage: "info.circle.fill")
                .font(.headline)
                .onTapGesture {
                    store.send(.setInfoSheetPresented(true))
                }

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

// MARK: - Shimmer Effect

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - ShimmerModifier

struct ShimmerModifier: ViewModifier {

    // MARK: Internal

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing)
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }

    // MARK: Private

    @State private var phase: CGFloat = 0

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
