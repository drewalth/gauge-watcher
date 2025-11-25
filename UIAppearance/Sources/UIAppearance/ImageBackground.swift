//
//  ImageBackground.swift
//  UIAppearance
//
//  Created by Andrew Althage on 11/25/25.
//

import SwiftUI

// MARK: - ImageBackground

public struct ImageBackground: View {

    private let image: String
    private let mode: Image.ResizingMode

    public init(image: String = "topography", mode: Image.ResizingMode = .tile) {
        self.image = image
        self.mode = mode
    }

    public var body: some View {
        GeometryReader { geo in
            AppImage.image(image)
                .resizable(resizingMode: mode) // This will tile the image
                .frame(width: geo.size.width, height: geo.size.height)
                .edgesIgnoringSafeArea(.all) // This will make it cover the whole screen including edges
        }
    }
}

// MARK: - AppImage

public enum AppImage {
    public static func image(_ name: String) -> Image {
        Image(name, bundle: Bundle.module)
    }
}

// MARK: - ImageBackgroundModifier

public struct ImageBackgroundModifier: ViewModifier {

    private let image: String
    private let scrollContentBackground: Visibility

    public init(image: String = "topography", scrollContentBackground: Visibility = .hidden) {
        self.scrollContentBackground = scrollContentBackground
        self.image = image
    }

    public func body(content: Content) -> some View {
        content
            .background(ImageBackground(image: image).ignoresSafeArea())
            .scrollContentBackground(scrollContentBackground)
    }
}

extension View {
    public func imageBackground(image: String = "topography", scrollContentBackground: Visibility = .hidden) -> some View {
        modifier(ImageBackgroundModifier(image: image, scrollContentBackground: scrollContentBackground))
    }
}
