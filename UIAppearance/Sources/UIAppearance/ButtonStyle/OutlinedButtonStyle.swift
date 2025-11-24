//
//  OutlinedButtonStyle.swift
//  UIAppearance
//
//  Created by Andrew Althage on 11/24/25.
//

import Foundation
import SwiftUI

/// A button style that displays an outlined button.
public struct OutlinedButtonStyle: ButtonStyle {

    // MARK: Lifecycle

    /// Creates a new instance of `OutlinedButtonStyle`.
    /// - Parameters:
    ///  - loading: A Boolean value that determines whether the button is in a loading state.
    ///  - disabled: A Boolean value that determines whether the button is disabled.
    public init(loading: Bool = false, disabled: Bool = false, variant: Variant = .primary) {
        self.loading = loading
        self.disabled = disabled
        self.variant = variant
    }

    // MARK: Public

    public enum Variant {
        case primary, destructive
    }

    public func makeBody(configuration: Configuration) -> some View {
        label(configuration)
            .frame(height: Theme.spacing(6))
            .frame(maxWidth: .infinity)
            .font(.body)
            .background(Color.clear.contentShape(Rectangle()))
            .foregroundColor(configuration.isPressed ? foregroundColor.opacity(0.8) : foregroundColor)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.spacing(1))
                    .stroke(configuration.isPressed ? foregroundColor.opacity(0.8) : foregroundColor, lineWidth: 4))
            .cornerRadius(Theme.spacing(1))
    }

    // MARK: Private

    private let loading: Bool
    private let disabled: Bool
    private let variant: Variant

    private var foregroundColor: Color {
        if disabled {
            Color.gray
        } else {
            switch variant {
            case .primary:
                Color.accentColor
            case .destructive:
                Color.red
            }
        }
    }

    @ViewBuilder
    private func label(_ configuration: Configuration) -> some View {
        if loading {
            ProgressView().frame(width: 20, height: 20)
        } else {
            configuration.label
        }
    }
}
