//
//  GaugeSearchMapFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import CoreLocation
import Loadable

@Reducer
struct GaugeSearchMapFeature {
    @ObservableState
    struct State {
        var currentUserLocation: CLLocationCoordinate2D?
    }
}
