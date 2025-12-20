//
//  WebBrowserService.swift
//  GaugeWatcherMac
//

import AppKit
import ComposableArchitecture
import SharedFeatures

// MARK: - SharedFeatures.WebBrowserService + DependencyKey

extension SharedFeatures.WebBrowserService: DependencyKey {
    public static let liveValue = SharedFeatures.WebBrowserService { url, _ in
        guard url.scheme == "http" || url.scheme == "https" else {
            throw SharedFeatures.WebBrowserErrors.invalidURL
        }

        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }
}
