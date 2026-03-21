import SwiftUI
import SwiftData

@main
struct LinguaDailyApp: App {
    @UIApplicationDelegateAdaptor(LinguaDailyAppDelegate.self) private var appDelegate

    private let modelContainer: ModelContainer
    @StateObject private var dependencyContainer: AppDependencyContainer

    init() {
        let schema = Schema([
            CachedDailyLessonEntity.self,
            CachedWordMetadataEntity.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.modelContainer = container
            _dependencyContainer = StateObject(wrappedValue: AppDependencyContainer(modelContext: container.mainContext))
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dependencyContainer.appState)
                .environmentObject(dependencyContainer)
                .onAppear {
                    LinguaDailyAppDelegate.onDeepLinkTarget = { target in
                        dependencyContainer.appState.handleDeepLink(target)
                    }
                    LinguaDailyAppDelegate.onPushOpened = { route in
                        dependencyContainer.analyticsService.track(.pushOpened, properties: ["route": route])
                    }
                }
                .onOpenURL { url in
                    guard let target = DeepLinkTarget(url: url) else {
                        return
                    }
                    dependencyContainer.appState.handleDeepLink(target)
                }
        }
        .modelContainer(modelContainer)
    }
}
