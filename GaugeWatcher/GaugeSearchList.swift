//
//  GaugeSearchList.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 9/17/25.
//

import GaugeSources
import SQLiteData
import SwiftUI

// MARK: - SearchScope

enum SearchScope: String, CaseIterable, Identifiable {
    case all, state, country, source
    var id: String { rawValue }
}

// struct GaugeSearchList: View {
//
//    @FetchAll var items: [Gauge]
//    @State var source: GaugeSource = .usgs
//    @State var state = "CO"
//    @State var order: SortOrder = .forward
//    @State var searchQuery = ""
//    @State private var selectedScope: SearchScope = .all
//
//    func getData() -> [Gauge] {
//        if searchQuery.isEmpty {
//            return items
//        } else {
//            return items.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
//        }
//    }
//
//    var body: some View {
//        NavigationStack {
//            List {
//                ForEach(getData()) { gauge in
//                    NavigationLink {
//                        GaugeDetailView(gauge.id)
//                    } label: {
//                        Text(gauge.name)
//                    }
//                }
//            }.navigationTitle("Gauges")
//        }
//        .gaugeWatcherList()
//        .task(id: [source, order, searchQuery] as [AnyHashable]) {
//            await updateQuery()
//        }.searchable(text: $searchQuery)
//        .searchScopes($selectedScope) {
//            ForEach(SearchScope.allCases) { scope in
//                Text(scope.rawValue.capitalized).tag(scope)
//            }
//        }.toolbar {
//            ToolbarItem(placement: .bottomBar) {
//                Button("Filter") {
//                    print("hello")
//                }
//            }
//        }
//    }
//
//    private func updateQuery() async {
//        do {
//            try await $items.load(
//                Gauge
//                    .where { $0.source == #bind(source) && $0.state == #bind(state) }
//                    .order {
//                        if order == .forward {
//                            $0.name
//                        } else {
//                            $0.name.desc()
//                        }
//                    }
//                    .limit(500))
//
//        } catch {
//            print(error.localizedDescription)
//        }
//    }
// }

// MARK: - SettingsView

struct SettingsView: View {
    var body: some View {
        Text("App Settings")
            .font(.largeTitle)
    }
}
