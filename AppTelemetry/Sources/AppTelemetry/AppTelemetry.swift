import Foundation
import os
import PostHog

public enum AppTelemetry {

    // MARK: Public

    public static func initialize() {
        let config = loadConfig()
        let posthogAPIKey = config["POSTHOG_API_KEY"] ?? ""
        let posthogHost = config["POSTHOG_HOST"] ?? ""

        if posthogHost.isEmpty || posthogAPIKey.isEmpty {
            logger.warning("Missing PostHog credentials")
            return
        }

        let posthogConfig = PostHogConfig(apiKey: posthogAPIKey, host: posthogHost)
        PostHogSDK.shared.setup(posthogConfig)
    }

    public static func captureEvent(_ name: String) {
        PostHogSDK.shared.capture(name)
    }

    // MARK: Private

    private static let logger = Logger(subsystem: "com.drewalth.GaugeWatcher", category: "AppTelemetry")

    private static func loadConfig() -> [String: String] {
        guard
            let configURL = Bundle.module.url(forResource: "config", withExtension: "plist"),
            let data = try? Data(contentsOf: configURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            logger.error("Failed to load config.plist")
            return [:]
        }

        return [
            "POSTHOG_API_KEY": plist["POSTHOG_API_KEY"] as? String ?? "",
            "POSTHOG_HOST": plist["POSTHOG_HOST"] as? String ?? ""
        ]
    }

}
