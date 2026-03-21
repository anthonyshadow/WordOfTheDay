# Integrations Handoff

## Sign in with Apple
- Add `Sign In with Apple` capability in Xcode target.
- Implement credential exchange in `AuthServiceProtocol` concrete implementation.
- Replace `StubAuthService.signInWithApple()` with nonce + identity token flow.

## Google Sign-In
- Add `GoogleSignIn` via Swift Package Manager.
- Configure iOS URL scheme and `GoogleService-Info.plist`.
- Replace `StubAuthService.signInWithGoogle()` with OAuth token exchange.

## Supabase
- Add `SUPABASE_URL` + `SUPABASE_ANON_KEY` in `Environment.xcconfig`.
- Implement concrete services using `APIClient` against Supabase REST/RPC.
- Run migrations from `supabase/migrations` with `supabase link --project-ref amrfdqdgrmvzpsmrtbnu` and `supabase db push`.

## APNs
- Enable push notifications capability.
- Register for remote notifications after onboarding consent.
- Upload APNs token with `PushRegistrationServiceProtocol` implementation.

## RevenueCat
- Add RevenueCat SPM package.
- Initialize SDK with `REVENUECAT_API_KEY`.
- Map customer info -> `SubscriptionState` in `RevenueCatSubscriptionService`.

## PostHog
- Add PostHog iOS SDK package.
- Initialize with `POSTHOG_API_KEY` and `POSTHOG_HOST`.
- Replace prints in `PostHogAnalyticsService` with `capture(...)` calls.

## Sentry
- Add Sentry Cocoa package.
- Initialize with `SENTRY_DSN`.
- Replace prints in `SentryCrashReportingService` with `SentrySDK.capture(error:)`.
