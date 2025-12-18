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
    Group {
      switch model.availability {
      case .available:
        ChatAvailableView(store: store)
      case .unavailable(.deviceNotEligible):
        UnavailableView(
          title: "Device Not Supported",
          message: "This device doesn't support Apple Intelligence.",
          systemImage: "iphone.slash")
      case .unavailable(.appleIntelligenceNotEnabled):
        UnavailableView(
          title: "Apple Intelligence Disabled",
          message: "Enable Apple Intelligence in Settings to use GaugeBot.",
          systemImage: "brain",
          helpURL: helpURL)
      case .unavailable(.modelNotReady):
        UnavailableView(
          title: "Model Downloading",
          message: "The language model is being prepared. Please try again shortly.",
          systemImage: "arrow.down.circle",
          isLoading: true)
      case .unavailable(let other):
        UnavailableView(
          title: "Unavailable",
          message: "GaugeBot is unavailable: \(other)",
          systemImage: "exclamationmark.triangle")
      }
    }
    .frame(minWidth: 400, minHeight: 400)
    .frame(maxWidth: 400, maxHeight: 400)
  }

  // MARK: Internal

  @Bindable var store: StoreOf<GaugeBotReducer>

  // MARK: Private

  private let model = SystemLanguageModel.default

  private var helpURL: URL? {
    #if os(macOS)
    URL(string: "https://support.apple.com/guide/mac-help/intro-to-apple-intelligence-mchl46361784/mac")
    #else
    nil
    #endif
  }
}

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
      TextField("Show me gauges on the Arkansas River...", text: $store.inputText)
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

// MARK: - MessageBubble

struct MessageBubble: View {

  // MARK: Internal

  let message: ChatMessage

  var body: some View {
    HStack {
      if isUser { Spacer(minLength: 60) }

      VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
        Text(message.content)
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(bubbleBackground)
          .foregroundStyle(isUser ? .white : .primary)
      }

      if !isUser { Spacer(minLength: 60) }
    }
  }

  // MARK: Private

  private var isUser: Bool {
    if case .user = message { return true }
    return false
  }

  private var bubbleBackground: some ShapeStyle {
    if isUser {
      return AnyShapeStyle(Color.accentColor)
    } else {
      return AnyShapeStyle(Color.primary.opacity(0.08))
    }
  }
}

// MARK: - TypingIndicator

struct TypingIndicator: View {

  // MARK: Internal

  var body: some View {
    HStack {
      HStack(spacing: 4) {
        ForEach(0..<3) { index in
          Circle()
            .fill(Color.secondary)
            .frame(width: 8, height: 8)
            .scaleEffect(animationOffset == index ? 1.2 : 0.8)
            .opacity(animationOffset == index ? 1.0 : 0.5)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(Color.primary.opacity(0.08), in: .capsule)

      Spacer(minLength: 60)
    }
    .onAppear {
      startAnimation()
    }
    .onDisappear {
      timerTask?.cancel()
    }
  }

  // MARK: Private

  @State private var animationOffset = 0
  @State private var timerTask: Task<Void, Never>?

  private func startAnimation() {
    timerTask = Task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.easeInOut(duration: 0.2)) {
          animationOffset = (animationOffset + 1) % 3
        }
      }
    }
  }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "bubble.left.and.bubble.right")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

      VStack(spacing: 8) {
        Text("Welcome to GaugeBot")
          .font(.headline)

        Text("Ask questions about water gauges, flow rates, and conditions.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.vertical, 60)
  }
}

// MARK: - ErrorStateView

struct ErrorStateView: View {
  let error: Error

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.red)

      Text("Something went wrong")
        .font(.headline)

      Text(error.localizedDescription)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}

// MARK: - UnavailableView

struct UnavailableView: View {
  let title: String
  let message: String
  let systemImage: String
  var helpURL: URL? = nil
  var isLoading = false

  var body: some View {
    VStack(spacing: 20) {
      if isLoading {
        ProgressView()
          .scaleEffect(1.5)
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