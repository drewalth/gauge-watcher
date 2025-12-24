//
//  ShimmerModifier.swift
//  SharedFeatures
//
//  Provides a shimmer animation effect for loading skeleton states.
//

import SwiftUI

// MARK: - ShimmerModifier

/// A view modifier that applies a shimmer animation effect, typically used for skeleton loading states.
public struct ShimmerModifier: ViewModifier {

    // MARK: Lifecycle

    public init() { }

    // MARK: Public

    public func body(content: Content) -> some View {
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

extension View {
    /// Applies a shimmer animation effect, useful for skeleton loading states.
    public func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Helpers

extension View {
    /// Creates a skeleton rectangle placeholder with shimmer effect.
    public func skeletonRect(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.primary.opacity(0.08))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .shimmering()
    }

    /// Creates a skeleton pill placeholder with shimmer effect.
    public func skeletonPill(width: CGFloat, height: CGFloat = 22) -> some View {
        Capsule()
            .fill(.primary.opacity(0.08))
            .frame(width: width, height: height)
            .shimmering()
    }
}

// MARK: - SkeletonRect

/// A standalone skeleton rectangle view with shimmer effect.
public struct SkeletonRect: View {

    // MARK: Lifecycle

    public init(width: CGFloat? = nil, height: CGFloat) {
        self.width = width
        self.height = height
    }

    // MARK: Public

    public var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.primary.opacity(0.08))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .shimmering()
    }

    // MARK: Private

    private let width: CGFloat?
    private let height: CGFloat

}

// MARK: - SkeletonPill

/// A standalone skeleton pill view with shimmer effect.
public struct SkeletonPill: View {

    // MARK: Lifecycle

    public init(width: CGFloat, height: CGFloat = 22) {
        self.width = width
        self.height = height
    }

    // MARK: Public

    public var body: some View {
        Capsule()
            .fill(.primary.opacity(0.08))
            .frame(width: width, height: height)
            .shimmering()
    }

    // MARK: Private

    private let width: CGFloat
    private let height: CGFloat

}
