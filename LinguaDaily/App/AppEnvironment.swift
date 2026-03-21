import Foundation

struct AppEnvironment {
    let supabaseURL: URL?
    let supabaseAnonKey: String?
    let posthogKey: String?
    let posthogHost: String?
    let revenueCatKey: String?
    let sentryDSN: String?
    let googleClientID: String?

    var supabaseConfig: SupabaseConfig? {
        guard let supabaseURL, let supabaseAnonKey, supabaseURL.host != nil else {
            return nil
        }
        return SupabaseConfig(projectURL: supabaseURL, anonKey: supabaseAnonKey)
    }

    static func load(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) -> AppEnvironment {
        AppEnvironment(
            supabaseURL: resolvedValue(infoKey: "SupabaseURL", envKey: "SUPABASE_URL", bundle: bundle, processInfo: processInfo).flatMap(URL.init(string:)),
            supabaseAnonKey: resolvedValue(infoKey: "SupabaseAnonKey", envKey: "SUPABASE_ANON_KEY", bundle: bundle, processInfo: processInfo),
            posthogKey: resolvedValue(infoKey: "PostHogAPIKey", envKey: "POSTHOG_API_KEY", bundle: bundle, processInfo: processInfo),
            posthogHost: resolvedValue(infoKey: "PostHogHost", envKey: "POSTHOG_HOST", bundle: bundle, processInfo: processInfo),
            revenueCatKey: resolvedValue(infoKey: "RevenueCatAPIKey", envKey: "REVENUECAT_API_KEY", bundle: bundle, processInfo: processInfo),
            sentryDSN: resolvedValue(infoKey: "SentryDSN", envKey: "SENTRY_DSN", bundle: bundle, processInfo: processInfo),
            googleClientID: resolvedValue(infoKey: "GoogleClientID", envKey: "GOOGLE_CLIENT_ID", bundle: bundle, processInfo: processInfo)
        )
    }

    private static func resolvedValue(
        infoKey: String,
        envKey: String,
        bundle: Bundle,
        processInfo: ProcessInfo
    ) -> String? {
        if let bundleValue = sanitize(bundle.object(forInfoDictionaryKey: infoKey) as? String) {
            return bundleValue
        }

        return sanitize(processInfo.environment[envKey])
    }

    private static func sanitize(_ value: String?) -> String? {
        guard var rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return nil
        }

        if rawValue.hasPrefix("\""), rawValue.hasSuffix("\""), rawValue.count >= 2 {
            rawValue.removeFirst()
            rawValue.removeLast()
        }

        if rawValue.hasPrefix("$(") || rawValue.hasPrefix("YOUR_") {
            return nil
        }

        return rawValue
    }
}
