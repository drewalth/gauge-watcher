//
//  Extensions.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//

import SwiftUI

extension View {
    /// Conditional view modifier.
    /// If the provided condition evaluates to 'true', the modifier is applied.
    /// - Parameters:
    ///  - condition: The condition to evaluate.
    ///  - transform: The view modifier to apply.
    ///  - Returns: The modified view.
    /// - Example:
    /// ```swift
    /// Text("Hello, World!")
    ///  .if(isLoading) {
    ///    $0.skeletonText()
    ///  }
    ///  ```
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func gaugeWatcherList() -> some View {
        modifier(GaugeWatcherListModifier())
    }
}
