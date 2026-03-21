import Foundation

struct SupabaseConfig {
    let projectURL: URL
    let anonKey: String

    static func fromEnvironment() -> SupabaseConfig? {
        guard
            let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
            let url = URL(string: urlString),
            let anon = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
        else {
            return nil
        }

        return SupabaseConfig(projectURL: url, anonKey: anon)
    }
}
