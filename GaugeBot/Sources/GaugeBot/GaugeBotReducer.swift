//
//  GaugeBotReducer.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import ComposableArchitecture
import Loadable

@Reducer
public struct GaugeBotReducer: Sendable {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  @ObservableState
  public struct State: Sendable, Equatable {
    public var messages: Loadable<[ChatMessage]>
    public var isWaitingForResponse: Bool
    public var inputText: String

    public init(
      messages: Loadable<[ChatMessage]> = .initial,
      isWaitingForResponse: Bool = false,
      inputText: String = "")
    {
      self.messages = messages
      self.isWaitingForResponse = isWaitingForResponse
      self.inputText = inputText
    }
  }

  public enum Action: Sendable, BindableAction {
    case binding(BindingAction<State>)
    case setMessages(Loadable<[ChatMessage]>)
    case addUserMessage(UserMessage)
    case addAssistantMessage(AssistantMessage)
    case sendMessage(String)
    case responseReceived(Result<String, Error>)
  }

  public var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .setMessages(let messages):
        state.messages = messages
        return .none

      case .addUserMessage(let message):
        var currentMessages = state.messages.unwrap() ?? []
        currentMessages.append(.user(message))
        state.messages = .loaded(currentMessages)
        return .none

      case .addAssistantMessage(let message):
        var currentMessages = state.messages.unwrap() ?? []
        currentMessages.append(.assistant(message))
        state.messages = .loaded(currentMessages)
        state.isWaitingForResponse = false
        return .none

      case .sendMessage(let message):
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          return .none
        }

        var currentMessages = state.messages.unwrap() ?? []
        currentMessages.append(.user(UserMessage(content: message)))
        state.messages = .loaded(currentMessages)
        state.isWaitingForResponse = true
        state.inputText = ""

        return .run { send in
          do {
            let response = try await gaugeBot.query(text: message)
            await send(.responseReceived(.success(response)))
          } catch {
            await send(.responseReceived(.failure(error)))
          }
        }

      case .responseReceived(.success(let response)):
        var currentMessages = state.messages.unwrap() ?? []
        currentMessages.append(.assistant(AssistantMessage(content: response)))
        state.messages = .loaded(currentMessages)
        state.isWaitingForResponse = false
        return .none

      case .responseReceived(.failure(let error)):
        var currentMessages = state.messages.unwrap() ?? []
        currentMessages.append(.assistant(AssistantMessage(content: "Error: \(error.localizedDescription)")))
        state.messages = .loaded(currentMessages)
        state.isWaitingForResponse = false
        return .none
      }
    }
  }

  // MARK: Private

  private let gaugeBot = GaugeBot()

}
