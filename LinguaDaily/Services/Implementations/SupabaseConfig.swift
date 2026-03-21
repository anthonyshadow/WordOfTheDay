import Foundation

struct SupabaseConfig {
    let projectURL: URL
    let anonKey: String

    static func fromEnvironment(_ environment: AppEnvironment = .load()) -> SupabaseConfig? {
        environment.supabaseConfig
    }
}
