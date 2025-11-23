//
//  GaugeSourceService.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import GaugeSources
import ComposableArchitecture

struct GaugeSourceService {
    var loadAll: () async throws -> [GaugeSourceItem]
}

extension GaugeSourceService: DependencyKey {
    static let liveValue: GaugeSourceService = Self(loadAll: {
        try await GaugeSources.loadAll()
    })
}

extension DependencyValues {
    var gaugeSourceService: GaugeSourceService {
        get { self[GaugeSourceService.self] }
        set { self[GaugeSourceService.self] = newValue }
    }
}
