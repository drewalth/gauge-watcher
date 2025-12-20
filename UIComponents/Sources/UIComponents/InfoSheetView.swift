//
//  InfoSheetView.swift
//  UIComponents
//
//  Created by Andrew Althage on 10/18/24.
//

import UIAppearance

import SwiftUI

/// A view that presents a sheet with a title and a close button.
/// This view is intended to be used as a modal sheet.
public struct InfoSheetView<Content: View>: View {

  // MARK: Lifecycle

  public init(title: String, onClose: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
    self.content = content()
    self.title = title
    self.onClose = onClose
  }

  // MARK: Public

  public var body: some View {
    NavigationStack {
      List {
        content
      }.navigationTitle(title)
        .listStyle(.inset)
        .presentationDetents([.medium])
      #if os(macOS)
        .frame(minWidth: 400)
        .frame(minHeight: 400)
        .padding(20)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark") {
              onClose()
            }
          }
        }
      #endif
    }
  }

  // MARK: Internal

  let onClose: () -> Void
  let content: Content
  let title: String

}

#Preview {
  InfoSheetView(title: "Test title") {
    print("Content")
  } content: {
    Text("Test")
  }
}
