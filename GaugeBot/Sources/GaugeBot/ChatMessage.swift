//
//  ChatMessage.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//
import Foundation

// MARK: - ChatMessage

public enum ChatMessage: Sendable, Identifiable, Equatable {
  case user(UserMessage)
  case assistant(AssistantMessage)

  // MARK: Public

  public var content: String {
    switch self {
    case .user(let userMessage):
      return userMessage.content
    case .assistant(let assistantMessage):
      return assistantMessage.content
    }
  }

  public var id: UUID {
    switch self {
    case .user(let userMessage):
      return userMessage.id
    case .assistant(let assistantMessage):
      return assistantMessage.id
    }
  }

  public static func createUserMessage(content: String) -> UserMessage {
    UserMessage(content: content)
  }

  public static func createAssistantMessage(content: String) -> AssistantMessage {
    AssistantMessage(content: content)
  }

}

// MARK: - UserMessage

public struct UserMessage: Sendable, Identifiable, Equatable {
  public let id: UUID
  public let content: String
  public init(content: String) {
    self.content = content
    id = UUID()
  }
}

// MARK: - AssistantMessage

public struct AssistantMessage: Sendable, Identifiable, Equatable {
  public let id: UUID
  public let content: String
  public init(content: String) {
    self.content = content
    id = UUID()
  }
}
