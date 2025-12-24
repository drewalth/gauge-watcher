//
//  OutlinedTileModifier.swift
//  SharedFeatures
//
//  Provides a polished card appearance with material background and subtle border.
//

import SwiftUI

// MARK: - OutlinedTileModifier

/// A view modifier that applies a polished card appearance with material background,
/// shadow, and a subtle gradient border.
public struct OutlinedTileModifier: ViewModifier {

    // MARK: Lifecycle

    public init() { }

    // MARK: Public

    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 1)
            }
    }
}

extension View {
    /// Applies a polished outlined tile appearance with material background and border.
    public func outlinedTile() -> some View {
        modifier(OutlinedTileModifier())
    }
}
