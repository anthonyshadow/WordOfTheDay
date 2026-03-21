# LinguaDaily (iOS V1 Scaffold)

Production-oriented SwiftUI + MVVM iPhone codebase scaffold for LinguaDaily, backed by Supabase.

## What is implemented
- App foundation: SwiftUI app shell, routing, tab navigation, dependency container, design system, reusable components.
- Auth + onboarding flow: welcome, goal/language/level/reminder, notification education, account creation/login (email + Apple/Google stubs).
- Today flow: daily word card, pronunciation action abstraction, examples, mark learned, favorite, save for review, share, word detail navigation.
- Review flow: spaced review queue, multiple-choice answer flow, immediate feedback, empty state.
- Archive: search, filter chips, sort menu, row navigation to word detail, free-tier archive limit policy.
- Progress + profile + settings: streak/accuracy stats, weekly module, profile cards, notification preferences, logout.
- Notifications foundation: local reminder scheduling + deep link routing (`linguadaily://today`, `linguadaily://review`) + APNs-ready delegate hooks.
- Subscription foundation: paywall UI + RevenueCat wrapper contract.
- Backend foundation: Supabase migrations, RLS, seed data (French + 20 words + pronunciation metadata + examples).
- Developer readiness: architecture docs, decision docs, integration handoff, env template, tests for core algorithms.

## Repository structure
- `LinguaDaily/`: iOS app source.
- `Docs/`: architecture, decisions, analytics, testing/integration docs.
- `Supabase/migrations/`: schema + seed SQL.
- `Tests/`: unit tests for review scheduling, daily assignment, and free-tier limits.
- `project.yml`: XcodeGen project definition.

## Setup
1. Install Xcode 15+.
2. Install XcodeGen (`brew install xcodegen`).
3. Generate project: `xcodegen generate`.
4. Copy `Config/Environment.xcconfig.template` -> `Config/Environment.xcconfig` and fill values.
5. Open `LinguaDaily.xcodeproj` and run on iPhone simulator.

## Supabase setup
1. Create Supabase project.
2. Run:
   - `Supabase/migrations/20260308130000_initial_schema.sql`
   - `Supabase/migrations/20260308131000_seed_french.sql`
3. Confirm RLS policies are active.

## V1 technical decisions
- Review intervals: `1 -> 3 -> 7 -> 14 -> 30` days; incorrect resets to 1 day.
- Mastery: 4 consecutive correct and at least 5 total attempts.
- Status model: `new`, `learned`, `review_due`, `mastered` + favorite overlay.
- Free tier archive cap: 30 words.
- Offline behavior: cached today lesson and archive metadata via SwiftData.

## Integrations currently stubbed
- Apple Sign-In token exchange
- Google Sign-In OAuth exchange
- RevenueCat purchase/restore
- PostHog event capture transport
- Sentry error transport
- APNs token upload

See `Docs/Integrations.md` for exact completion steps.
