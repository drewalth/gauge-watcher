//
//  GaugeSourceService.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import ComposableArchitecture
import GaugeSources

// MARK: - GaugeSourceService

struct GaugeSourceService {
    var loadAll: () async throws -> [GaugeSourceItem]
}

// MARK: DependencyKey

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
