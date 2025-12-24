//
//  FilterIndicatorBanner.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/23/25.
//

import SwiftUI

// MARK: - FilterIndicatorBanner

/// A compact banner that indicates filters are currently applied to the map.
/// Displays in the bottom-right corner with a clear action button.
struct FilterIndicatorBanner: View {

    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.secondary)

            Text("Filters Active")
                .font(.callout)
                .foregroundStyle(.primary)

            Button("Clear", action: onClear)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.blue.opacity(0.3)
        FilterIndicatorBanner(onClear: { })
    }
    .frame(width: 400, height: 300)
}

