//
//  MessageBubble.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import MarkdownView
import SwiftUI

// MARK: - MessageBubble

struct MessageBubble: View {

    // MARK: Internal

    let message: ChatMessage

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Group {
                    if isUser {
                        Text(message.content)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    } else {
                        MarkdownUI(body: message.content)
                    }
                }
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

#Preview("MessageBubble - User") {
    MessageBubble(message: .user(UserMessage(content: "Hello, how are you?")))
}

#Preview("MessageBubble - Assistant") {
    MessageBubble(message: .assistant(AssistantMessage(content: "I'm doing well, thank you!")))
}

#Preview("Multiple Messages") {
    VStack(spacing: 12) {
        MessageBubble(message: .user(UserMessage(content: "Hello, how are you?")))
        MessageBubble(message: .assistant(AssistantMessage(content: "I'm doing well, thank you!")))
        MessageBubble(message: .user(UserMessage(content: "What is the weather in Tokyo?")))
        MessageBubble(message: .assistant(AssistantMessage(content: "The weather in Tokyo is sunny and 20 degrees Celsius.")))
    }.padding()
}
