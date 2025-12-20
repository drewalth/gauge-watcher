//
//  OnboardingTips.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/20/25.
//
import TipKit
import AppTelemetry
import SharedFeatures
import os

enum OnboardingTips {
    static private let logger = Logger(category: "OnboardingTips")
    static func initialize() {
        do {
            try Tips.configure()
            logger.info("onboarding tips initialized")
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }
    
    static var searchMode = SearchModeTip()
    
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
}


