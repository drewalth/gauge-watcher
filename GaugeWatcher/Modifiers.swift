//
//  Modifiers.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//
import SwiftUI

struct GaugeWatcherListModifier: ViewModifier {

    public init() {
        //    UINavigationBar.appearance().largeTitleTextAttributes = [.font : Theme.getUIFont(.h1)]
    }

    @Environment(\.colorScheme) var colorScheme

    public func body(content: Content) -> some View {
        content
            .listRowSpacing(8)
            .listStyle(.insetGrouped)
            .if(colorScheme == .light) {
                $0.shadow(color: Color.gray.opacity(0.15), radius: 4, x: 0, y: 4)
            }
    }
}
