//
//  GaugeListRow.swift
//  SharedFeatures
//
//  A reusable list row for displaying gauge information.
//

import GaugeSources
import SwiftUI

// MARK: - GaugeListRow

/// A list row displaying gauge name, source, state, and zone with a source-colored indicator.
public struct GaugeListRow: View {

    // MARK: Lifecycle

    public init(gauge: GaugeRef, onTap: @escaping () -> Void) {
        self.gauge = gauge
        self.onTap = onTap
    }

    // MARK: Public

    public var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Source indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(gauge.source.displayColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(gauge.name)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(gauge.source.rawValue.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(gauge.source.displayColor)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(gauge.state)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !gauge.zone.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(gauge.zone)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            #if os(macOS)
            .background(isHovering ? Color.primary.opacity(0.06) : .clear)
            #endif
            .clipShape(.rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
        #endif
    }

    // MARK: Private

    #if os(macOS)
    @State private var isHovering = false
    #endif

    private let gauge: GaugeRef
    private let onTap: () -> Void

}

// MARK: - FavoriteGaugeListRow

/// A list row for favorite gauges, showing a star indicator instead of source bar.
public struct FavoriteGaugeListRow: View {

    // MARK: Lifecycle

    public init(gauge: GaugeRef, onTap: @escaping () -> Void) {
        self.gauge = gauge
        self.onTap = onTap
    }

    // MARK: Public

    public var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(gauge.name)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(gauge.source.rawValue.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(gauge.source.displayColor)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(gauge.state)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            #if os(macOS)
            .background(isHovering ? Color.primary.opacity(0.06) : .clear)
            #endif
            .clipShape(.rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
        #endif
    }

    // MARK: Private

    #if os(macOS)
    @State private var isHovering = false
    #endif

    private let gauge: GaugeRef
    private let onTap: () -> Void

}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        GaugeListRow(gauge: .preview) { }
        Divider()
        FavoriteGaugeListRow(gauge: .preview) { }
    }
    .padding()
}
