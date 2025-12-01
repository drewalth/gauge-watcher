//
//  UtilityBlockView.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 12/1/25.
//

import SwiftUI
import VComponents

public struct UtilityBlockView: View {

  // MARK: Lifecycle

  public init(title: String? = nil, message: String? = nil, kind: Kind) {
    self.title = title
    self.message = message
    self.kind = kind
  }

  // MARK: Public

  public enum Kind {
    case error(String)
    case loading
    case empty
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 12) {
      icon()
        .font(.title2)
        .foregroundStyle(iconColor())

      VStack(alignment: .leading, spacing: 6) {
        if let title {
          Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
        }

        if let message {
          Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        content()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(backgroundColor()))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(borderColor(), lineWidth: 1))
  }

  // MARK: Private

  private let title: String?
  private let message: String?
  private let kind: Kind

  @ViewBuilder
  private func icon() -> some View {
    switch kind {
    case .error:
      Image(systemName: "exclamationmark.triangle.fill")
    case .loading:
      VContinuousSpinner(uiModel: {
        var model = VContinuousSpinnerUIModel()
        model.dimension = 20
        return model
      }())
        .padding(.trailing, 10)
    case .empty:
      Image(systemName: "tray.fill")
    }
  }

  @ViewBuilder
  private func content() -> some View {
    switch kind {
    case .error(let errorMessage):
      if errorMessage != message {
        Text(errorMessage)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    case .loading:
      if title == nil, message == nil {
        Text("Loading...")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    case .empty:
      Text("No data available")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  private func backgroundColor() -> Color {
    switch kind {
    case .error:
      return Color.red.opacity(0.08)
    case .loading:
      return Color.blue.opacity(0.06)
    case .empty:
      return Color.secondary.opacity(0.06)
    }
  }

  private func borderColor() -> Color {
    switch kind {
    case .error:
      return Color.red.opacity(0.2)
    case .loading:
      return Color.blue.opacity(0.15)
    case .empty:
      return Color.secondary.opacity(0.15)
    }
  }

  private func iconColor() -> Color {
    switch kind {
    case .error:
      return .red
    case .loading:
      return .blue
    case .empty:
      return .secondary
    }
  }

}

#Preview("Loading State") {
  VStack(spacing: 16) {
    UtilityBlockView(kind: .loading)
    UtilityBlockView(
      title: "Fetching Gauges",
      message: "Please wait while we load your data",
      kind: .loading)
  }
  .padding()
}

#Preview("Empty State") {
  VStack(spacing: 16) {
    UtilityBlockView(kind: .empty)
    UtilityBlockView(
      title: "No Gauges Found",
      message: "Add your first gauge to get started",
      kind: .empty)
  }
  .padding()
}

#Preview("Error State") {
  VStack(spacing: 16) {
    UtilityBlockView(kind: .error("Network connection failed"))
    UtilityBlockView(
      title: "Sync Failed",
      message: "Unable to reach the server",
      kind: .error("Check your internet connection and try again"))
  }
  .padding()
}

#Preview("All States") {
  VStack(spacing: 16) {
    UtilityBlockView(
      title: "Loading Data",
      message: "Syncing with server",
      kind: .loading)
    UtilityBlockView(
      title: "No Results",
      message: "Try adjusting your filters",
      kind: .empty)
    UtilityBlockView(
      title: "Error Occurred",
      message: "Something went wrong",
      kind: .error("Invalid response from server"))
  }
  .padding()
}
