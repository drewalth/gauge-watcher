//
//  DateExt.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/24/25.
//

import GaugeDrivers
import Foundation

extension Date {
    func isInTimePeriod(predefinedPeriod: TimePeriod.PredefinedPeriod) -> Bool {
        switch predefinedPeriod {
        case .last24Hours:
            return isInLast24Hours()
        case .last7Days:
            return isInLast7Days()
        case .last30Days:
            return isInLast30Days()
        case .last90Days:
            return isInLast90Days()
        }
    }
    
    private func isInLast24Hours() -> Bool {
        return self >= Date().addingTimeInterval(-24 * 60 * 60)
    }

    private func isInLast7Days() -> Bool {
        return self >= Date().addingTimeInterval(-7 * 24 * 60 * 60)
    }

    private func isInLast30Days() -> Bool {
        return self >= Date().addingTimeInterval(-30 * 24 * 60 * 60)
    }

    private func isInLast90Days() -> Bool {
        return self >= Date().addingTimeInterval(-90 * 24 * 60 * 60)
    }
}
