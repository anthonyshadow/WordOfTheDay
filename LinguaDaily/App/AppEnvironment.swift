import Foundation

struct AppEnvironment {
    let supabaseURL: URL?
    let supabaseAnonKey: String?
    let posthogKey: String?
    let revenueCatKey: String?
    let sentryDSN: String?

    static func load() -> AppEnvironment {
        AppEnvironment(
            supabaseURL: ProcessInfo.processInfo.environment["SUPABASE_URL"].flatMap(URL.init(string:)),
            supabaseAnonKey: ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"],
            posthogKey: ProcessInfo.processInfo.environment["POSTHOG_API_KEY"],
            revenueCatKey: ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"],
            sentryDSN: ProcessInfo.processInfo.environment["SENTRY_DSN"]
        )
    }
}
