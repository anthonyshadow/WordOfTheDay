# LinguaDaily V1 Technical Architecture

## Product Scope (V1)
- iPhone-first SwiftUI app with MVVM.
- One active language per user.
- One assigned daily word per user per day.
- Daily lesson includes pronunciation, definition, and 2-3 example sentences.
- Lightweight spaced review, archive/search, progress, reminders, and subscriptions.

## App Architecture
- UI: SwiftUI views organized by feature.
- State: `ObservableObject` ViewModels (`@MainActor`) with `AsyncPhase` UI state.
- Navigation: Root `NavigationStack` + tab shell. Deep links route into Today or Review.
- Dependency injection: `AppDependencyContainer` provided via environment.
- Data layers:
  - Remote layer: typed `URLSession` API client for Supabase REST/RPC/Edge routes.
  - Local cache layer: SwiftData for daily lesson and archive metadata.
  - Domain layer: pure Swift models and review scheduling logic.

## Folder Layout
```text
LinguaDaily/
  App/
  Core/
    Models/
    Persistence/
    Utilities/
  DesignSystem/
    Components/
  Shared/
    Components/
  Services/
    Protocols/
    Implementations/
      Stubs/
  Features/
    Splash/
    Onboarding/
    Auth/
    MainTabs/
    Today/
    WordDetail/
    Review/
    Archive/
    Progress/
    Profile/
    Settings/
    Paywall/
Docs/
supabase/
  migrations/
Tests/
```

## State Management
- Global app state (`AppState`) stores:
  - auth session status
  - onboarding completion
  - active route/deep link target
  - entitlement
- Feature ViewModels:
  - own feature state
  - call protocol-based services
  - map service errors to user-facing `ViewError`
- State transitions are deterministic and testable:
  - `loading -> success`
  - `loading -> empty`
  - `loading -> failure`

## Service Boundaries
- `AuthServiceProtocol`: email auth, Apple auth bridge, Google placeholder bridge, session restore/logout.
- `OnboardingServiceProtocol`: persist onboarding inputs and completion.
- `DailyLessonServiceProtocol`: fetch/assign today word, word detail.
- `ReviewServiceProtocol`: fetch due queue, submit answer, compute next interval.
- `ArchiveServiceProtocol`: search/filter/sort learned words.
- `ProgressServiceProtocol`: streaks, mastered count, accuracy, weekly activity.
- `NotificationServiceProtocol`: permission, reminder schedule, deep-link payload handling.
- `SubscriptionServiceProtocol`: entitlement state + paywall purchase/restore wrapper.
- `AnalyticsServiceProtocol`: typed event capture.
- `CrashReportingServiceProtocol`: error capture abstraction.

## Networking
- `APIClient` wraps `URLSession`.
- Supports:
  - Supabase REST endpoints for CRUD
  - RPC endpoints for assignment/review scheduling
  - optional Edge Function routes
- Auth uses bearer token in headers when available.

## Local Persistence and Offline
- SwiftData models cache:
  - today lesson payload (`CachedDailyLesson`)
  - archive metadata (`CachedWordMetadata`)
- Offline behavior:
  - today screen loads cached lesson when network fails
  - archive shows cached records and last sync timestamp
  - review submits are queued in-memory for retry in this scaffold (documented for production queueing)

## Error Handling Pattern
- Services throw typed `AppError`.
- ViewModels map to `ViewError` with retry action.
- UI uses unified loading/empty/error components.
- Errors are also sent to `CrashReportingService` with context.

## Loading/Empty/Error Pattern
- Loading: skeleton/shimmer card or `ProgressView` state card.
- Empty: explicit action-oriented empty cards.
- Error: compact card with retry button.

## Security and Auth
- Supabase Auth as source of identity.
- Public schema tables include RLS policies by `auth.uid()`.
- Write access is limited to row owner except static content tables.

## Integrations Strategy (V1)
- Apple Sign-In: native `AuthenticationServices` bridge (stubbed token exchange in scaffold).
- Google Sign-In: provider abstraction with placeholder adapter.
- RevenueCat/PostHog/Sentry: protocol wrappers + stub implementations until keys are set.
- APNs: local notification path now, APNs token registration interface included.
