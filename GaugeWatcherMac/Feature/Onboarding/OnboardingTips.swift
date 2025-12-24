//
//  OnboardingTips.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/20/25.
//
import AppTelemetry
import os
import TipKit

enum OnboardingTips {

    static func initialize() {
        do {
            try Tips.configure()
            logger.info("onboarding tips initialized")
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }

    // MARK: Private

    static private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GaugeWatcherMac",
        category: "OnboardingTips")
}
