//
//  MessageBubble.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import SwiftUI

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
