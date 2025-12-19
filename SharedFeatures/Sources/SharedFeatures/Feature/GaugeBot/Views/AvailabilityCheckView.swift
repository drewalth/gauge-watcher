//
//  AvailabilityCheckView.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import FoundationModels
import SwiftUI

// MARK: - AvailabilityCheckView

struct AvailabilityCheckView<Content: View>: View {

    // MARK: Lifecycle

    init(modelAvailability: SystemLanguageModel.Availability, @ViewBuilder content: () -> Content) {
        self.modelAvailability = modelAvailability
        self.content = content()
    }

    // MARK: Internal

    @ViewBuilder var content: Content

    var body: some View {
        Group {
            switch modelAvailability {
            case .available:
                content
            case .unavailable(.deviceNotEligible):
                UnavailableViewContent(
                    title: "Device Not Supported",
                    message: "This device doesn't support Apple Intelligence.",
                    systemImage: "iphone.slash")
            case .unavailable(.appleIntelligenceNotEnabled):
                UnavailableViewContent(
                    title: "Apple Intelligence Disabled",
                    message: "Enable Apple Intelligence in Settings to use GaugeBot.",
                    systemImage: "brain",
                    helpURL: helpURL)
            case .unavailable(.modelNotReady):
                UnavailableViewContent(
                    title: "Model Downloading",
                    message: "The language model is being prepared. Please try again shortly.",
                    systemImage: "arrow.down.circle",
                    isLoading: true)
            case .unavailable(let other):
                UnavailableViewContent(
                    title: "Unavailable",
                    message: "GaugeBot is unavailable: \(other)",
                    systemImage: "exclamationmark.triangle")
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .frame(maxWidth: 400, maxHeight: 400)
    }

    // MARK: Private

    private let modelAvailability: SystemLanguageModel.Availability

    private var helpURL: URL? {
        #if os(macOS)
        URL(string: "https://support.apple.com/guide/mac-help/intro-to-apple-intelligence-mchl46361784/mac")
        #else
        nil
        #endif
    }

}

// MARK: - UnavailableViewContent

struct UnavailableViewContent: View {
    let title: String
    let message: String
    let systemImage: String
    var helpURL: URL?
    var isLoading = false

    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .bold()

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let helpURL {
                Link("Learn More", destination: helpURL)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
    }
}

#Preview("AvailabilityCheckView - Available") {
    AvailabilityCheckView(modelAvailability: .available) {
        ChatAvailableView(store: Store(initialState: GaugeBotReducer.State(), reducer: { GaugeBotReducer() }))
    }
}

#Preview("AvailabilityCheckView - Unavailable - Device Not Supported") {
    AvailabilityCheckView(modelAvailability: .unavailable(.deviceNotEligible)) {
        ChatAvailableView(store: Store(initialState: GaugeBotReducer.State(), reducer: { GaugeBotReducer() }))
    }
}

#Preview("AvailabilityCheckView - Unavailable - Apple Intelligence Not Enabled") {
    AvailabilityCheckView(modelAvailability: .unavailable(.appleIntelligenceNotEnabled)) {
        ChatAvailableView(store: Store(initialState: GaugeBotReducer.State(), reducer: { GaugeBotReducer() }))
    }
}

#Preview("AvailabilityCheckView - Unavailable - Model Not Ready") {
    AvailabilityCheckView(modelAvailability: .unavailable(.modelNotReady)) {
        ChatAvailableView(store: Store(initialState: GaugeBotReducer.State(), reducer: { GaugeBotReducer() }))
    }
}
