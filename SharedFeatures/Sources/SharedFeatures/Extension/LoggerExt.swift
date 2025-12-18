//
//  LoggerExt.swift
//  SharedFeatures
//

import os

extension Logger {
  public init(category: String) {
    self.init(subsystem: "com.drewalth.GaugeWatcher", category: category)
  }
}


