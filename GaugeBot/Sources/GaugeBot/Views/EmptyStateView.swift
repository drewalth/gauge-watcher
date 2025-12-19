//
//  EmptyStateView.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import SwiftUI

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
