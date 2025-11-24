//
//  GaugeFavoriteToggle.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import SwiftUI

struct GaugeFavoriteToggle: View {

    let onPress: () -> Void
    let isFavorite: Bool

    var body: some View {
        Button {
            onPress()
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .symbolRenderingMode(.palette)
                .foregroundStyle(isFavorite ? .yellow : .gray)
                .labelStyle(.iconOnly)
        }
    }
}
