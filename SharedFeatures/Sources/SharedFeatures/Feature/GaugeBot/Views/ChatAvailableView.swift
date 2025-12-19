//
//  ChatAvailableView.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import SwiftUI
import AppTelemetry

// MARK: - ChatAvailableView

struct ChatAvailableView: View {

    // MARK: Internal

    @Bindable var store: StoreOf<GaugeBotReducer>

    var body: some View {
        VStack(spacing: 0) {
            messagesSection
            Divider()
            inputSection
        }
        .trackView("ChatAvailableView", {
            return [
                "MessagesCount": store.messages.unwrap()?.count ?? 0,
            ]
        }())
    }

    // MARK: Private

    @FocusState private var isInputFocused: Bool

    @ViewBuilder
    private var messagesSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    messagesContent
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .onChange(of: store.messages.unwrap()?.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private var messagesContent: some View {
        switch store.messages {
        case .initial:
            EmptyStateView()
        case .loading:
            ProgressView("Loading messages...")
        case .loaded(let messages), .reloading(let messages):
            if messages.isEmpty {
                EmptyStateView()
            } else {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                        .id(message.id)
                }

                if store.isWaitingForResponse {
                    TypingIndicator()
                        .id("typing-indicator")
                }
            }
        case .error(let error):
            ErrorStateView(error: error)
        }
    }

    private var inputSection: some View {
        HStack(spacing: 12) {
            TextField("Ask a question...", text: $store.inputText)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .disabled(store.isWaitingForResponse)
                .onSubmit {
                    submitMessage()
                }
                #if os(macOS)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05)))
            #endif

            Button("Send", systemImage: "arrow.up.circle.fill") {
                submitMessage()
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .disabled(store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isWaitingForResponse)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }

    private func submitMessage() {
        let trimmed = store.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.send(.sendMessage(trimmed))
        isInputFocused = true
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if store.isWaitingForResponse {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            }
        } else if let lastMessage = store.messages.unwrap()?.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}
