//
//  ReadingRefWithinTimePeriod.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//
import GaugeDrivers

func readingsInTimePeriod(readings: [GaugeReadingRef], timePeriod: TimePeriod) -> [GaugeReadingRef] {
    return readings.filter { isInTimePeriod(reading: $0, timePeriod: timePeriod) }
}

 func isInTimePeriod(reading: GaugeReadingRef, timePeriod: TimePeriod) -> Bool {
    switch timePeriod {
    case .predefined(let predefinedPeriod):
        return reading.createdAt.isInTimePeriod(predefinedPeriod: predefinedPeriod)
    case .custom(let start, let end):
        return reading.createdAt >= start && reading.createdAt <= end
    }
}
