//
//  GaugeSourcesExt.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/23/25.
//

import GaugeSources
import SQLiteData

// MARK: - GaugeSource + QueryBindable

extension GaugeSource: QueryBindable { }

// MARK: - GaugeSourceMetric + QueryBindable

extension GaugeSourceMetric: QueryBindable { }
