// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI

public enum Theme {
    public static func spacing(_ multiplier: CGFloat = 1) -> CGFloat {
        6 * multiplier
    }
}
