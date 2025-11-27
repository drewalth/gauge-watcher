//
//  GaugeMapMarker.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//
import ComposableArchitecture
import SwiftUI

struct GaugeMapMarker: View {

    // MARK: Lifecycle

    init(store: StoreOf<GaugeSearchFeature>, gauge: GaugeRef) {
        self.gauge = gauge
        self.store = store
    }

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeSearchFeature>

    var body: some View {
        ZStack {
            // hack to incread tap area
            Circle()
                .fill(Color.clear)
                .frame(width: 30, height: 30)
            Circle()
                .fill(color)
                .strokeBorder(.white, lineWidth: 3)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .foregroundColor(color))
        }.onTapGesture {
            popoverVisible.toggle()
        }
        .popover(isPresented: $popoverVisible) {
            VStack(alignment: .leading) {
                Text(gauge.name)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .font(.callout)
                    .bold()
                    .layoutPriority(1)

                Button {
                    popoverVisible.toggle()
                    store.send(.goToGaugeDetail(gauge.id))
                } label: {
                    Label("View", systemImage: "arrow.right")
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }.frame(minWidth: 150, maxHeight: 400)
            .frame(maxWidth: 250)
            .padding(16)
            .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: Private

    // TODO: add type-safe key
    @AppStorage("gauge-map-marker-color") private var color = Color(hex: "#27F5C2")
    @State private var popoverVisible = false

    private let gauge: GaugeRef

}
