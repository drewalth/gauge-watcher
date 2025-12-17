//
//  SettingsView.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/17/25.
//

import CoreLocation
import SharedFeatures
import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    // MARK: Internal

    var body: some View {
        Form {
            locationSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 450, maxWidth: 550)
        .task {
            await observeLocationAuthorization()
        }
    }

    // MARK: Private

    @State private var authorizationStatus: CLAuthorizationStatus = .notDetermined

    @ViewBuilder
    private var locationSection: some View {
        Section {
            LabeledContent("Status") {
                HStack(spacing: 6) {
                    statusIndicator
                    Text(statusDescription)
                        .foregroundStyle(statusColor)
                }
            }

            if authorizationStatus == .denied || authorizationStatus == .restricted {
                Text("Gauge Watcher uses your location to show nearby water gauges. You can enable this in System Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if authorizationStatus != .authorizedAlways {
                Button("Open Location Settings") {
                    openLocationSettings()
                }
            }
        } header: {
            Label("Location", systemImage: "location")
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            "Not Requested"
        case .restricted:
            "Restricted"
        case .denied:
            "Denied"
        case .authorizedAlways:
            "Enabled"
        @unknown default:
            "Unknown"
        }
    }

    private var statusColor: Color {
        switch authorizationStatus {
        case .authorizedAlways:
            .green
        case .denied, .restricted:
            .red
        case .notDetermined:
            .orange
        @unknown default:
            .secondary
        }
    }

    private func observeLocationAuthorization() async {
        @Dependency(\.locationService) var locationService
        authorizationStatus = locationService.currentAuthorizationStatus

        for await action in await locationService.delegate() {
            switch action {
            case .initialState(let status, _):
                authorizationStatus = status
            case .didChangeAuthorization(let status):
                authorizationStatus = status
            default:
                break
            }
        }
    }

    private func openLocationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
