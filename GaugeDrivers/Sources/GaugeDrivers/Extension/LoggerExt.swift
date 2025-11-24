//
//  LoggerExt.swift
//  GaugeDrivers
//
//  Created by Andrew Althage on 11/24/25.
//

import Foundation
import os

extension Logger {
    init(category: String) {
        self.init(subsystem: "com.drewalth.GaugeDrivers", category: category)
    }
}
