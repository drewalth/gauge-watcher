//
//  GaugeSourceItemExt.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Foundation

// MARK: - Helper Protocol for GaugeSourceItem Integration
//
// This file provides helper functions to bridge between GaugeSources metadata
// and GaugeDrivers. Since these are separate packages, you should add these
// extensions to your app's bridging layer that imports both packages.
//
// Example usage in your app:
//
//   import GaugeSources
//   import GaugeDrivers
//
//   extension GaugeSourceItem {
//       func toDriverOptions(...) -> GaugeDriverOptions {
//           // implementation
//       }
//   }

/// Helper function to convert a GaugeSource string to GaugeDriverSource
/// Use this in your app layer to bridge the two packages
public func gaugeDriverSource(from sourceString: String) -> GaugeDriverSource? {
    switch sourceString.uppercased() {
    case "USGS":
        return .usgs
    case "ENVIRONMENT_CANADA":
        return .environmentCanada
    case "LAWA":
        return .lawa
    case "DWR":
        return .dwr
    default:
        return nil
    }
}

/// Helper function to create metadata for Environment Canada gauges
/// - Parameters:
///   - stateCode: The province/state code (e.g., "BC", "ON")
/// - Returns: SourceMetadata with the appropriate province
public func environmentCanadaMetadata(stateCode: String) -> SourceMetadata? {
    let provinceCode = stateCode.lowercased()
    guard let province = EnvironmentCanada.Province(rawValue: provinceCode) else {
        return nil
    }
    return .environmentCanada(province: province)
}

