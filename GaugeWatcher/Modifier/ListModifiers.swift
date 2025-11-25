//
//  ListModifiers.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import SwiftUI
import UIAppearance

// MARK: - GaugeWatcherListModifier

struct GaugeWatcherListModifier: ViewModifier {

    public init() {
        //    UINavigationBar.appearance().largeTitleTextAttributes = [.font : Theme.getUIFont(.h1)]
    }

    @Environment(\.colorScheme) var colorScheme

    public func body(content: Content) -> some View {
        content
            .listRowSpacing(8)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .imageBackground()
            .if(colorScheme == .light) {
                $0.shadow(color: Color.gray.opacity(0.15), radius: 4, x: 0, y: 4)
            }
    }
}

extension View {
    func gaugeWatcherList() -> some View {
        modifier(GaugeWatcherListModifier())
    }
}
