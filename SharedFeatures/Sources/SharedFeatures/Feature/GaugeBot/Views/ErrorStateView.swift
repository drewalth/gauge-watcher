//
//  ErrorStateView.swift
//  GaugeBot
//
//  Created by Andrew Althage on 12/18/25.
//

import SwiftUI

// MARK: - ErrorStateView

/// Displays error information when the chat encounters a failure.
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
