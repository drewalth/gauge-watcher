//
//  GaugeDetailHeader.swift
//  SharedFeatures
//
//  A hero header for gauge detail views with badges and location info.
//

import GaugeSources
import SwiftUI

// MARK: - GaugeDetailHeader

/// A hero header displaying gauge name, badges, and location information.
public struct GaugeDetailHeader: View {

    // MARK: Lifecycle

    public init(gauge: GaugeRef?) {
        self.gauge = gauge
    }

    // MARK: Public

    public var body: some View {
        if let gauge {
            content(gauge)
        } else {
            skeletonContent
        }
    }

    // MARK: Private

    private let gauge: GaugeRef?

    @ViewBuilder
    private func content(_ gauge: GaugeRef) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Badges row
            HStack(spacing: 8) {
                GaugeSourceBadge(source: gauge.source)

                if gauge.favorite {
                    favoriteBadge
                }

                GaugeStatusBadge(gauge: gauge)

                Spacer()
            }

            // Gauge name
            Text(gauge.name)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            // Location info
            VStack(alignment: .leading, spacing: 4) {
                Label(gauge.state, systemImage: "mappin.circle.fill")
                Label("Site \(gauge.siteID)", systemImage: "number.circle.fill")
                    .textSelection(.enabled)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var favoriteBadge: some View {
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

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Badges skeleton
            HStack(spacing: 8) {
                SkeletonPill(width: 80)
                SkeletonPill(width: 60)
            }

            // Name skeleton
            SkeletonRect(height: 24)

            // Location skeleton
            VStack(alignment: .leading, spacing: 4) {
                SkeletonRect(width: 120, height: 14)
                SkeletonRect(width: 100, height: 14)
            }
        }
    }
}

// MARK: - GaugeDetailHeaderCompact

/// A compact header for use in list rows or smaller spaces.
public struct GaugeDetailHeaderCompact: View {

    // MARK: Lifecycle

    public init(gauge: GaugeRef) {
        self.gauge = gauge
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(gauge.name)
                .font(.headline)

            GaugeStatusBadge(gauge: gauge)
        }
    }

    // MARK: Private

    private let gauge: GaugeRef

}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        GaugeDetailHeader(gauge: .preview)

        Divider()

        GaugeDetailHeader(gauge: nil)

        Divider()

        GaugeDetailHeaderCompact(gauge: .preview)
    }
    .padding()
}

