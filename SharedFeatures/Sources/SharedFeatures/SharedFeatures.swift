//
//  SharedFeatures.swift
//  SharedFeatures
//
//  Central module for shared features across iOS and macOS targets.
//

// MARK: - Re-exports for convenience

@_exported import AppDatabase
@_exported import ComposableArchitecture
@_exported import GaugeService
@_exported import GaugeSources
@_exported import Loadable

// MARK: - Public API

// Features - Note: Avoid naming conflicts with SwiftUI (e.g., no `App` typealias)
public typealias GaugeSearch = GaugeSearchFeature
public typealias GaugeDetail = GaugeDetailFeature
public typealias FavoriteGauges = FavoriteGaugesFeature
public typealias FavoriteGaugeTile = FavoriteGaugeTileFeature

// Services (protocols - implementations provided by app targets)
// - LocationServiceProtocol
// - WebBrowserService

// Models
// - GaugeRef
// - GaugeReadingRef
// - CurrentLocation

// Constants
// - LocalStorageKey
