import PostHog

public enum AppTelemetry {
    public static func initialize() {
        let POSTHOG_API_KEY = ""
        // usually 'https://us.i.posthog.com' or 'https://eu.i.posthog.com'
        let POSTHOG_HOST = ""

        let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        PostHogSDK.shared.setup(config)
    }
}
