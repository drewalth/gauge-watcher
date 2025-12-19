//
//  GaugeBotChatView.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import ComposableArchitecture
import FoundationModels
import SwiftUI

// MARK: - GaugeBotChatView

// TODO: prettier styling of assistant Markdown responses
public struct GaugeBotChatView: View {

    // MARK: Lifecycle

    public init(store: StoreOf<GaugeBotReducer>) {
        self.store = store
    }

    // MARK: Public

    public var body: some View {
        AvailabilityCheckView(modelAvailability: model.availability) {
            ChatAvailableView(store: store)
        }
    }

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeBotReducer>

    // MARK: Private

    private let model = SystemLanguageModel.default
}
