//
//  GaugeSearchMapFeature.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import Loadable
import CoreLocation

@Reducer
struct GaugeSearchMapFeature {
    @ObservableState
    struct State {
        var currentUserLocation: CLLocationCoordinate2D?
    }
}
