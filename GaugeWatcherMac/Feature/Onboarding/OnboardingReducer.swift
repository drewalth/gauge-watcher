//
//  OnboardingReducer.swift
//  GaugeWatcherMac
//
//  Re-exports the shared OnboardingReducer for macOS use.
//  The actual implementation lives in SharedFeatures.
//

import SharedFeatures

// Re-export the shared OnboardingReducer for use in macOS views.
// The shared reducer handles all the logic; macOS just provides the view layer.
public typealias MacOnboardingReducer = SharedFeatures.OnboardingReducer
