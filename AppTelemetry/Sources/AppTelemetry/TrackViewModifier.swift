//
//  TrackViewModifier.swift
//  AppTelemetry
//
//  Created by Andrew Althage on 11/24/25.
//

import PostHog
import SwiftUI

// MARK: - TrackViewModifier

public struct TrackViewModifier: ViewModifier {
    public init(
        _ screenName: String? = nil,
        _ properties: [String: Any]? = nil) {
        self.properties = properties
        self.screenName = screenName
    }

    private let screenName: String?
    private let properties: [String: Any]?

    public func body(content: Content) -> some View {
        content
            .postHogScreenView(screenName, properties)
    }
}

extension View {
    public func trackView(
        _ screenName: String? = nil,
        _ properties: [String: Any]? = nil)
    -> some View {
        modifier(TrackViewModifier(screenName, properties))
    }
}
