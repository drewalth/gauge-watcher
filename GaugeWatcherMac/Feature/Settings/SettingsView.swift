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
            aboutSection
            linksSection
            acknowledgementsSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 450, maxWidth: 550)
        .task {
            await observeLocationAuthorization()
        }
    }

    // MARK: Private

    @State private var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
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
    private var aboutSection: some View {
        Section {
            LabeledContent("Version") {
                Text("\(appVersion) (\(buildNumber))")
                    .foregroundStyle(.secondary)
            }

            Text("Gauge Watcher helps you monitor water levels at stream gauges across the United States, Canada, and New Zealand.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }

    @ViewBuilder
    private var linksSection: some View {
        Section {
            Link(destination: URL(string: "https://gaugewatcher.com/privacy.html")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://github.com/drewalth/gauge-watcher")!) {
                Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Link(destination: URL(string: "https://github.com/drewalth/gauge-watcher/issues")!) {
                Label("Report an Issue", systemImage: "ladybug")
            }

            Link(destination: URL(string: "https://github.com/drewalth/gauge-watcher/blob/main/LICENSE")!) {
                Label("License", systemImage: "doc.text")
            }
        } header: {
            Label("Links", systemImage: "link")
        }
    }

    @ViewBuilder
    private var acknowledgementsSection: some View {
        Section {
            Text("Data provided by USGS, Environment Canada, Colorado DWR, and LAWA (New Zealand).")
                .font(.callout)
                .foregroundStyle(.secondary)
        } header: {
            Label("Acknowledgements", systemImage: "heart")
        } footer: {
            Text("© 2025 Andrew Althage")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
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
