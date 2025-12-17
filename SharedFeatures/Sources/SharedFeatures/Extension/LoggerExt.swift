//
//  LoggerExt.swift
//  SharedFeatures
//

import os

public extension Logger {
    init(category: String) {
        self.init(subsystem: "com.drewalth.GaugeWatcher", category: category)
    }
}

