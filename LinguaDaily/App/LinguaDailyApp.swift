import SwiftUI
import SwiftData

@main
struct LinguaDailyApp: App {
    @UIApplicationDelegateAdaptor(LinguaDailyAppDelegate.self) private var appDelegate

    private let isRunningTests: Bool
    private let modelContainer: ModelContainer
    @StateObject private var dependencyContainer: AppDependencyContainer

    init() {
        let isRunningTests = Self.isRunningTests
        self.isRunningTests = isRunningTests
        let schema = Schema([
            CachedDailyLessonEntity.self,
            CachedWordMetadataEntity.self,
            CachedWordEnrichmentEntity.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isRunningTests)
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.modelContainer = container
            _dependencyContainer = StateObject(
                wrappedValue: AppDependencyContainer(
                    modelContext: container.mainContext,
                    modelContainer: container,
                    testingMode: isRunningTests
                )
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isRunningTests {
                    Color.clear
                } else {
                    RootView()
                        .environmentObject(dependencyContainer.appState)
                        .environmentObject(dependencyContainer)
                        .preferredColorScheme(colorScheme(for: dependencyContainer.appState.appearancePreference))
                        .onAppear {
                            LinguaDailyAppDelegate.onDeepLinkTarget = { target in
                                dependencyContainer.appState.handleDeepLink(target)
                            }
                            LinguaDailyAppDelegate.onPushOpened = { route in
                                dependencyContainer.analyticsService.track(.pushOpened, properties: ["route": route])
                            }
                            LinguaDailyAppDelegate.onPushTokenReceived = { tokenData in
                                Task {
                                    do {
                                        try await dependencyContainer.pushRegistrationService.registerDeviceToken(tokenData)
                                    } catch {
                                        dependencyContainer.crashService.capture(error, context: ["feature": "push_token_register"])
                                    }
                                }
                            }
                        }
                        .onOpenURL { url in
                            guard let target = DeepLinkTarget(url: url) else {
                                return
                            }
                            dependencyContainer.appState.handleDeepLink(target)
                        }
                }
            }
        }
        .modelContainer(modelContainer)
    }

    private func colorScheme(for preference: AppearancePreference) -> ColorScheme? {
        switch preference {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
