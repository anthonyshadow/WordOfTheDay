# LinguaDaily

LinguaDaily is an iPhone-first SwiftUI language-learning app built around one daily word, lightweight spaced review, and a Supabase-backed account, onboarding, and progress model.

## Current status
- Core product flows are live against Supabase: email auth, onboarding sync, daily lessons, review, archive, profile, settings, and progress.
- PostHog and Sentry are integrated in the app and loaded from local config.
- RevenueCat is wired app-side with a safe free-tier fallback when its key or products are not configured yet.
- Apple Sign In, Google Sign-In, paid App Store subscription products, Apple signing, and TestFlight still wait on Apple developer enrollment.

## What is working
- Supabase email signup, login, session restore, logout, and account deletion
- Onboarding synced to remote `profiles` and `notification_preferences`
- Live language picker backed by Supabase
- Daily lesson assignment, word detail actions, related words, review queue, archive, and progress metrics from the live backend
- Editable profile data saved to Supabase
- Settings for reminders, preferred accent, daily learning mode, and appearance saved to Supabase
- Streaks and best retention category computed from real backend activity instead of placeholder values
- Local notification scheduling plus APNs device-token persistence hook once iOS provides a token
- PostHog capture with identify/reset and basic sensitive-field redaction
- Sentry crash/error reporting with user binding, redaction, and a debug test event
- Offline-friendly lesson caching via SwiftData fallback

## Seeded languages
The repo currently seeds these live languages into Supabase:
- French
- Spanish
- Japanese
- Italian
- Korean
- Mandarin
- German

Each seeded language currently includes starter words, example sentences, and audio rows in the backend migrations under [`supabase/migrations`](/Users/anthonyshadowitz/Desktop/WordApp/supabase/migrations).

## Tech stack
- SwiftUI + MVVM
- XcodeGen for project generation
- Supabase Auth + Postgres
- SwiftData for local caching
- PostHog, Sentry, RevenueCat

## Repository layout
- `LinguaDaily/`: app source
- `Tests/`: unit tests
- `Docs/`: architecture and provider notes
- `supabase/migrations/`: schema, seed data, auth trigger, and profile/settings migrations
- `project.yml`: XcodeGen source of truth

## Prerequisites
- A recent Xcode install with the iOS SDK version expected by [`project.yml`](/Users/anthonyshadowitz/Desktop/WordApp/project.yml)
- `xcodegen`
- Node.js 20+ and `npm`

## Local setup
1. Install Node dependencies:

```bash
npm install
```

2. Copy the environment template:

```bash
cp Config/Environment.xcconfig.template Config/Environment.xcconfig
```

3. Fill in the values in [`Config/Environment.xcconfig`](/Users/anthonyshadowitz/Desktop/WordApp/Config/Environment.xcconfig).

4. Generate the Xcode project:

```bash
xcodegen generate
```

5. Open `LinguaDaily.xcodeproj` in Xcode and run the app on a simulator.

If you want a truly fresh-user flow in the simulator, log out first or delete the app from the simulator before relaunching.

## Environment values
- `SUPABASE_URL`: required for auth and app data
- `SUPABASE_ANON_KEY`: required for auth and app data
- `POSTHOG_API_KEY`: required if you want analytics events to reach PostHog
- `POSTHOG_HOST`: required for the PostHog cloud region, usually `https://us.i.posthog.com` or `https://eu.i.posthog.com`
- `REVENUECAT_API_KEY`: optional until you are ready to wire subscriptions for real
- `SENTRY_DSN`: optional but recommended for crash/error reporting
- `SENTRY_AUTH_TOKEN`: optional, only needed if you want Xcode builds to upload dSYMs with `sentry-cli`
- `GOOGLE_CLIENT_ID`: reserved for future Google Sign-In setup

Keep URL-style values quoted exactly like the template. In `.xcconfig` files, unquoted `https://...` values can be truncated because of `//` parsing.

## Supabase setup
The repo ships with a local CLI wrapper in [`package.json`](/Users/anthonyshadowitz/Desktop/WordApp/package.json), so you do not need a globally installed `supabase` binary.

1. Log in:

```bash
npm run db:login
```

2. Link the repo to your project:

```bash
npm run db:link
```

3. Inspect migration status if needed:

```bash
npm run db:migrations
```

4. Push migrations:

```bash
npm run db:push
```

If your remote database already contains schema objects from an earlier manual setup, you may need `supabase migration repair --linked --status applied <version>` before pushing. The dedicated Supabase notes live in [`supabase/README.md`](/Users/anthonyshadowitz/Desktop/WordApp/supabase/README.md).

## Running and testing
Run the app from Xcode with the `LinguaDaily` scheme, or run tests from the command line. Adjust the simulator destination if needed for your machine.

```bash
xcodebuild -scheme LinguaDaily -project /Users/anthonyshadowitz/Desktop/WordApp/LinguaDaily.xcodeproj -destination 'platform=iOS Simulator,OS=26.3.1,name=iPhone 17' test
```

The current suite covers auth, onboarding, notifications, profile, settings, daily lesson, word detail, review, archive, progress, analytics/crash wiring, subscriptions, and domain logic.

## Provider status
Configured now:
- Supabase
- PostHog
- Sentry
- RevenueCat app-side wrapper and paywall flow

App-side ready but still dependent on Apple/platform setup:
- APNs device token upload path in the app
- Remote push delivery and capabilities

Still pending external setup:
- Apple Sign In
- Google Sign-In
- RevenueCat products / App Store connection
- Apple signing, App Store Connect, and TestFlight

## Notes
- [`project.yml`](/Users/anthonyshadowitz/Desktop/WordApp/project.yml) is the source of truth for the Xcode project. If you change packages, build settings, or capabilities, regenerate the project with `xcodegen generate`.
- [`Config/Environment.xcconfig`](/Users/anthonyshadowitz/Desktop/WordApp/Config/Environment.xcconfig) is local machine config and should stay out of version control.
- Simulator runs will not produce a real APNs device token.
- Additional architecture detail is in [`Docs/Architecture.md`](/Users/anthonyshadowitz/Desktop/WordApp/Docs/Architecture.md).
