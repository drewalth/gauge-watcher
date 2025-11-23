//
//  LoggerExtension.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import os

extension Logger {
    init(category: String) {
        self.init(subsystem: "com.drewalth.GaugeWatcher", category: category)
    }
}
