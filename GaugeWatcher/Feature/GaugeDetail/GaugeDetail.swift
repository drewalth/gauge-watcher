//
//  GaugeDetail.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import SwiftUI

struct GaugeDetail: View {
    @Bindable var store: StoreOf<GaugeDetailFeature>

    var body: some View {
        Text("GaugeDeatil")
            .task {
                store.send(.load)
            }
    }
}
