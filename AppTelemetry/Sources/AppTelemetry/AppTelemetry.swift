import os
import PostHog

public enum AppTelemetry {
    private static let logger = Logger(subsystem: "com.drewalth.GaugeWatcher", category: "AppTelemetry")
    public static func initialize() {
        let posthogAPIKey = ""
        // usually 'https://us.i.posthog.com' or 'https://eu.i.posthog.com'
        let posthogHost = ""

        if posthogHost.isEmpty || posthogAPIKey.isEmpty {
            logger.warning("Missing PostHog credentials")
            return
        }

        let config = PostHogConfig(apiKey: posthogAPIKey, host: posthogHost)
        PostHogSDK.shared.setup(config)
    }
}
