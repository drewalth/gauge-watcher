//
//  MessageBubble.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import MarkdownView
import SwiftUI

// MARK: - MessageBubble

/// Chat bubble for user (right-aligned, accent) or assistant (left-aligned, Markdown) messages.
struct MessageBubble: View {

    // MARK: Internal

    let message: ChatMessage

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if isUser {
                    Text(message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                } else {
                    MarkdownUI(body: message.content, css: Self.assistantCSS, styled: false)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    // MARK: Private

    /// CSS for assistant Markdown bubbles. Uses `color-scheme: light dark` and
    /// Apple system semantic colors for automatic appearance adaptation.
    private static let assistantCSS = """
    :root {
      color-scheme: light dark;
    }

    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    html, body {
      font: -apple-system-body;
      font-size: 15px;
      line-height: 1.5;
      color: -apple-system-label;
      background: transparent;
      -webkit-text-size-adjust: 100%;
      overflow: hidden;
      -webkit-user-select: text;
      user-select: text;
    }

    p {
      margin: 0 0 0.75em 0;
    }

    p:last-child {
      margin-bottom: 0;
    }

    h1, h2, h3, h4, h5, h6 {
      font-weight: 600;
      margin: 0 0 0.5em 0;
      line-height: 1.3;
    }

    h1 { font-size: 1.5em; }
    h2 { font-size: 1.3em; }
    h3 { font-size: 1.15em; }
    h4, h5, h6 { font-size: 1em; }

    ul, ol {
      margin: 0 0 0.75em 0;
      padding-left: 1.5em;
    }

    ul:last-child, ol:last-child {
      margin-bottom: 0;
    }

    li {
      margin: 0.25em 0;
    }

    li > ul, li > ol {
      margin: 0.25em 0;
    }

    code {
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, monospace;
      font-size: 0.9em;
      background: rgba(128, 128, 128, 0.15);
      padding: 0.15em 0.4em;
      border-radius: 4px;
    }

    pre {
      margin: 0.75em 0;
      padding: 0.75em;
      background: rgba(128, 128, 128, 0.1);
      border-radius: 6px;
      overflow-x: auto;
      -webkit-overflow-scrolling: touch;
    }

    pre:last-child {
      margin-bottom: 0;
    }

    pre code {
      background: none;
      padding: 0;
      font-size: 0.85em;
      line-height: 1.4;
    }

    blockquote {
      margin: 0.75em 0;
      padding-left: 1em;
      border-left: 3px solid rgba(128, 128, 128, 0.4);
      color: -apple-system-secondary-label;
    }

    blockquote:last-child {
      margin-bottom: 0;
    }

    a {
      color: -apple-system-blue;
      text-decoration: none;
    }

    strong {
      font-weight: 600;
    }

    hr {
      border: none;
      border-top: 1px solid rgba(128, 128, 128, 0.3);
      margin: 1em 0;
    }

    table {
      border-collapse: collapse;
      margin: 0.75em 0;
      font-size: 0.9em;
      width: 100%;
    }

    th, td {
      padding: 0.4em 0.6em;
      border: 1px solid rgba(128, 128, 128, 0.3);
      text-align: left;
    }

    th {
      font-weight: 600;
      background: rgba(128, 128, 128, 0.1);
    }

    img {
      max-width: 100%;
      height: auto;
      border-radius: 6px;
    }
    """

    private var isUser: Bool {
        if case .user = message { return true }
        return false
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
