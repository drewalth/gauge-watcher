//
//  TypingIndicator.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import SwiftUI

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
