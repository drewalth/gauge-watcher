//
//  OnboardingTips.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/20/25.
//
import AppTelemetry
import os
import SharedFeatures
import TipKit

enum OnboardingTips {

    // MARK: Internal

    struct SearchModeTip: Tip {
        var title: Text {
            Text("Switch Search Modes")
        }

        var message: Text? {
            Text("Use Map View to find gauges in the visible area, or switch to Filters to search by location and data source.")
        }

        var image: Image? {
            Image(systemName: "slider.horizontal.3")
        }
    }

    static var searchMode = SearchModeTip()

    static func initialize() {
        do {
            try Tips.configure()
            logger.info("onboarding tips initialized")
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }

    // MARK: Private

    static private let logger = Logger(category: "OnboardingTips")
}
