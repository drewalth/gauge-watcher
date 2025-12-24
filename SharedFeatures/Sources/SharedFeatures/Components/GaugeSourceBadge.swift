//
//  GaugeSourceBadge.swift
//  SharedFeatures
//
//  Displays the data source of a gauge with an appropriate color and icon.
//

import GaugeSources
import SwiftUI

// MARK: - GaugeSourceBadge

/// Displays a badge indicating the gauge's data source.
public struct GaugeSourceBadge: View {

    // MARK: Lifecycle

    public init(source: GaugeSource) {
        self.source = source
    }

    // MARK: Public

    public var body: some View {
        let style = sourceStyle
        Label(source.rawValue, systemImage: style.icon)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(style.color.opacity(0.15))
            }
            .foregroundStyle(style.color)
    }

    // MARK: Private

    private let source: GaugeSource

    private var sourceStyle: (color: Color, icon: String) {
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

// MARK: - GaugeSource Color Helper

extension GaugeSource {
    /// The display color associated with this data source.
    public var displayColor: Color {
        switch self {
        case .usgs:
            .blue
        case .environmentCanada:
            .red
        case .dwr:
            .orange
        case .lawa:
            .teal
        }
    }

    /// The display name for this data source.
    public var displayName: String {
        switch self {
        case .usgs:
            "USGS (US Geological Survey)"
        case .dwr:
            "DWR (CO Dept. of Water Resources)"
        case .environmentCanada:
            "Environment Canada"
        case .lawa:
            "LAWA (NZ Land, Air, Water)"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        GaugeSourceBadge(source: .usgs)
        GaugeSourceBadge(source: .dwr)
        GaugeSourceBadge(source: .environmentCanada)
        GaugeSourceBadge(source: .lawa)
    }
    .padding()
}

