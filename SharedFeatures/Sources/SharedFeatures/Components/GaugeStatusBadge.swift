//
//  GaugeStatusBadge.swift
//  SharedFeatures
//
//  Displays the operational status of a gauge (Current, Stale, or Inactive).
//

import AppDatabase
import SwiftUI

// MARK: - GaugeStatusBadge

/// Displays a badge indicating the gauge's operational status.
public struct GaugeStatusBadge: View {

    // MARK: Lifecycle

    public init(gauge: GaugeRef) {
        self.gauge = gauge
    }

    // MARK: Public

    public var body: some View {
        let info = statusInfo
        Label(info.label, systemImage: info.icon)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(info.color.opacity(0.15))
            }
            .foregroundStyle(info.color)
    }

    // MARK: Private

    private let gauge: GaugeRef

    private var statusInfo: (label: String, icon: String, color: Color) {
        switch gauge.status {
        case .inactive:
            return ("Inactive", "exclamationmark.triangle.fill", .red)
        case .unknown, .active:
            let isStale = gauge.isStale()
            return isStale
                ? ("Stale", "clock.badge.exclamationmark", .orange)
                : ("Current", "checkmark.circle", .green)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        GaugeStatusBadge(gauge: .preview)
    }
    .padding()
}

extension GaugeRef {
    /// Preview gauge for SwiftUI previews.
    static var preview: GaugeRef {
        GaugeRef(
            id: 1,
            name: "Colorado River at Lees Ferry",
            siteID: "09380000",
            metric: .cfs,
            country: "US",
            state: "AZ",
            zone: "Lower Colorado",
            source: .usgs,
            favorite: true,
            primary: true,
            latitude: 36.8652,
            longitude: -111.5877,
            updatedAt: Date(),
            createdAt: Date(),
            status: .active)
    }
}
