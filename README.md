# LinguaDaily

LinguaDaily is an iPhone-first SwiftUI language-learning app built around one daily word, lightweight spaced review, and a Supabase-backed account and progress model.

## Current status
- Real backend flows are wired for email/password auth, onboarding sync, daily lessons, review, archive, and progress.
- PostHog analytics and Sentry crash reporting are integrated and loaded from local config.
- RevenueCat is wired app-side with a safe fallback when its key is missing.
- Apple Sign In, Google Sign-In, APNs device token upload, and TestFlight/App Store setup are intentionally deferred until Apple developer setup is in place.

## What is working
- Supabase email signup, login, session restore, and logout
- Onboarding synced to remote `profiles` and `notification_preferences`
- Live language picker backed by Supabase
- Daily lesson assignment and word detail loading from Supabase
- Save for review, spaced review queue updates, archive, and progress metrics
- Local reminder scheduling and deep-link routing
- PostHog event capture with identify/reset support and basic redaction
- Sentry crash reporting with user binding and redaction
- Unit tests covering auth, onboarding, review, archive, subscriptions, crash reporting, and core domain logic

## Tech stack
- SwiftUI + MVVM
- XcodeGen for project generation
- Supabase Auth + Postgres
- SwiftData for local caching/offline fallbacks
- PostHog, Sentry, RevenueCat

## Repository layout
- `LinguaDaily/`: app source
- `Tests/`: unit tests
- `Docs/`: architecture and provider notes
- `supabase/migrations/`: schema, seed data, and auth trigger migrations
- `project.yml`: XcodeGen source of truth

## Prerequisites
- A recent Xcode install with the iOS 26 SDK that matches [`project.yml`](/Users/anthonyshadowitz/Desktop/WordApp/project.yml)
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

## Environment values
- `SUPABASE_URL`: required for auth and app data
- `SUPABASE_ANON_KEY`: required for auth and app data
- `POSTHOG_API_KEY`: required if you want analytics events to reach PostHog
- `POSTHOG_HOST`: required for PostHog cloud region, usually `https://us.i.posthog.com` or `https://eu.i.posthog.com`
- `REVENUECAT_API_KEY`: optional until you are ready to wire subscriptions for real
- `SENTRY_DSN`: optional but recommended for crash/error reporting
- `SENTRY_AUTH_TOKEN`: optional, only needed if you want Xcode builds to upload dSYMs with `sentry-cli`
- `GOOGLE_CLIENT_ID`: not used yet, reserved for future Google Sign-In setup

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

## Testing
Run tests from Xcode or from the command line. Adjust the simulator destination if needed for your machine.

```bash
xcodebuild -scheme LinguaDaily -project /Users/anthonyshadowitz/Desktop/WordApp/LinguaDaily.xcodeproj -destination 'platform=iOS Simulator,OS=26.3.1,name=iPhone 17' test
```

## Provider status
Configured now:
- Supabase
- PostHog
- Sentry
- RevenueCat app-side wrapper and paywall flow

Still pending external setup:
- Apple Sign In
- Google Sign-In
- APNs remote push registration
- RevenueCat products / App Store connection
- Apple signing, App Store Connect, and TestFlight

## Notes
- [`project.yml`](/Users/anthonyshadowitz/Desktop/WordApp/project.yml) is the source of truth for the Xcode project. If you change packages, build settings, or capabilities, regenerate the project with `xcodegen generate`.
- [`Config/Environment.xcconfig`](/Users/anthonyshadowitz/Desktop/WordApp/Config/Environment.xcconfig) is local machine config and should stay out of version control.
- Additional architecture detail is in [`Docs/Architecture.md`](/Users/anthonyshadowitz/Desktop/WordApp/Docs/Architecture.md).
