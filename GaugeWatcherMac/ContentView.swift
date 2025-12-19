//
//  ContentView.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/16/25.
//

import GaugeBot
import SharedFeatures
import SwiftUI

// MARK: - ContentView

struct ContentView: View {

    // MARK: Internal

    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            switch store.initialized {
            case .initial, .loading:
                ProgressView("Loading...")
                    .task {
                        store.send(.initialize)
                    }
            case .reloading:
                mainContent
                    .overlay {
                        ProgressView()
                    }
            case .loaded(let isInitialized):
                if isInitialized {
                    mainContent
                } else {
                    errorView("Failed to initialize")
                }
            case .error(let error):
                errorView(error.localizedDescription)
            }
        }
    }

    // MARK: Private

    @State private var inspectorMode: InspectorMode = .nearby
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var sheetIsPresented = false

    @ViewBuilder
    private var mainContent: some View {
        if let gaugeSearchStore = store.scope(state: \.gaugeSearch, action: \.gaugeSearch) {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                GaugeListInspector(
                    gaugeSearchStore: gaugeSearchStore,
                    favoritesStore: store.scope(state: \.favorites, action: \.favorites),
                    mode: $inspectorMode)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
                    .toolbar(removing: .sidebarToggle)
            } detail: {
                GaugeSearchView(store: gaugeSearchStore)
                    .ignoresSafeArea(.container, edges: .all)
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Toggle Sidebar", systemImage: "sidebar.leading") {
                        withAnimation {
                            columnVisibility = columnVisibility == .all ? .detailOnly : .all
                        }
                    }
                    .keyboardShortcut("s", modifiers: [.command, .option])
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if gaugeSearchStore.path.isEmpty {
                        inspectorModeToggle
                    }
                    Button {
                        sheetIsPresented.toggle()
                    }
                    label: {
                        Label("GaugeBot", systemImage: "bubble.left.and.bubble.right")
                            .accessibilityLabel("Chat with GaugeBot")
                            .accessibilityHint("Chat with GaugeBot to get information about water gauges")
                            .accessibilityValue("Chat with GaugeBot")
                            .labelStyle(.titleAndIcon)

                    }.buttonStyle(.borderedProminent)
                }

            }.sheet(isPresented: $sheetIsPresented) {
                NavigationStack {
                    GaugeBotChatView(store: store.scope(state: \.gaugeBot, action: \.gaugeBot))
                        .navigationTitle("GaugeBot")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close", systemImage: "xmark") {
                                    sheetIsPresented.toggle()
                                }
                            }
                        }
                }
            }
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private var inspectorModeToggle: some View {
        Picker("Mode", selection: $inspectorMode) {
            Label("Search", systemImage: "map")
                .tag(InspectorMode.nearby)
            Label("Favorites", systemImage: "star")
                .tag(InspectorMode.favorites)
        }
        .pickerStyle(.segmented)
        .labelStyle(.titleAndIcon)
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView(
            "Error",
            systemImage: "exclamationmark.triangle",
            description: Text(message))
    }
}

// MARK: - InspectorMode

enum InspectorMode: Hashable {
    case nearby
    case favorites
}

// MARK: - Preview

#Preview {
    ContentView(store: Store(initialState: AppFeature.State()) {
        AppFeature()
    })
}
