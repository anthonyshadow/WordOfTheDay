# LinguaDaily

LinguaDaily is an iPhone-first SwiftUI language-learning app built around one daily word, lightweight spaced review, and a Supabase-backed account, onboarding, and progress model.

## Current status
- Core product flows are live against Supabase: email auth, onboarding sync, daily lessons, review, archive, profile, settings, and progress.
- Daily lesson enrichment is live app-side with Wiktionary metadata, Forvo native-speaker pronunciation lookup, Google Cloud Text-to-Speech fallback, and resilient offline caching.
- Translate v1 is implemented with text, voice, and camera translation plus saved/favorited translation library flows backed by Supabase.
- PostHog and Sentry are integrated in the app and loaded from local config.
- RevenueCat is wired app-side with a safe free-tier fallback when its key or products are not configured yet.
- Apple Sign In, Google Sign-In, paid App Store subscription products, Apple signing, and TestFlight still wait on Apple developer enrollment.

## What is working
- Supabase email signup, login, session restore, logout, and account deletion
- Onboarding synced to remote `profiles` and `notification_preferences`
- Live language picker backed by Supabase
- Daily lesson assignment, word detail actions, related words, review queue, archive, and progress metrics from the live backend
- Daily lesson enrichment that keeps Supabase as the primary source of truth, then layers in Wiktionary definitions/examples/pronunciation notes, Forvo audio, and Google TTS fallback without breaking the base lesson flow
- Idempotent persistence of newly discovered externally sourced words back into Supabase using normalized lemma + language matching
- Editable profile data saved to Supabase
- Settings for reminders, preferred accent, daily learning mode, and appearance saved to Supabase
- Streaks and best retention category computed from real backend activity instead of placeholder values
- Translate tab with text input, voice transcription, camera OCR, source-language detection, save/favorite, copy/share, and saved-library detail flows
- Local notification scheduling plus APNs device-token persistence hook once iOS provides a token
- PostHog capture with identify/reset and basic sensitive-field redaction
- Sentry crash/error reporting with user binding, redaction, and a debug test event
- Offline-friendly lesson caching via SwiftData fallback, including a 7-day cache for enriched word metadata and pronunciation references

## Daily lesson enrichment
- Supabase still provides the base lesson and remains the primary source of truth.
- When `fetchTodayLesson()` succeeds online, the app launches Wiktionary, Forvo, and Google TTS requests in parallel where appropriate, with a 5-second timeout per provider call.
- Provider failures are isolated. If one or all enrichment providers fail, the app still returns the base lesson instead of surfacing an app-breaking error.
- Enrichment results are cached locally in SwiftData for 7 days so previously enriched content can still be served offline.
- If external enrichment returns a valid word for a language that does not already exist in Supabase, the app persists it through the `upsert_external_word` RPC using conservative lemma normalization and duplicate prevention.
- Google TTS audio is used as a fallback when Forvo does not return a usable pronunciation track. TTS-generated local files are cached for device playback, while only remotely hosted audio references are persisted back to Supabase.

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
- URLSession-based provider integrations for Wiktionary, Forvo, and Google Cloud Text-to-Speech
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

3. Fill in the values in [`Config/Environment.xcconfig`](/Users/anthonyshadowitz/Desktop/WordApp/Config/Environment.xcconfig). `FORVO_API_KEY` and `GOOGLE_TTS_API_KEY` are optional, but leaving them empty disables those provider paths.

4. Generate the Xcode project:

```bash
xcodegen generate
```

5. Open `LinguaDaily.xcodeproj` in Xcode and run the app on a simulator.

If you want a truly fresh-user flow in the simulator, log out first or delete the app from the simulator before relaunching.

For Translate specifically, the simulator is still useful for builds and unit tests, but real end-to-end voice and camera translation should be verified on a physical iPhone or iPad because Apple camera capture is unavailable in the simulator and Apple's Translation framework does not perform live translation there.

## Environment values
- `SUPABASE_URL`: required for auth and app data
- `SUPABASE_ANON_KEY`: required for auth and app data
- `POSTHOG_API_KEY`: required if you want analytics events to reach PostHog
- `POSTHOG_HOST`: required for the PostHog cloud region, usually `https://us.i.posthog.com` or `https://eu.i.posthog.com`
- `REVENUECAT_API_KEY`: optional until you are ready to wire subscriptions for real
- `SENTRY_DSN`: optional but recommended for crash/error reporting
- `SENTRY_AUTH_TOKEN`: optional, only needed if you want Xcode builds to upload dSYMs with `sentry-cli`
- `GOOGLE_CLIENT_ID`: reserved for future Google Sign-In setup
- `FORVO_API_KEY`: optional, enables native-speaker pronunciation lookup from Forvo
- `GOOGLE_TTS_API_KEY`: optional, enables Google Cloud Text-to-Speech pronunciation fallback when Forvo has no usable audio
- `GOOGLE_TTS_VOICE_NAME`: optional, lets you pin a specific Google Cloud TTS voice such as `es-ES-Standard-A`

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

The current daily lesson enrichment flow expects the additive migration [`20260322193000_add_word_enrichment_support.sql`](/Users/anthonyshadowitz/Desktop/WordApp/supabase/migrations/20260322193000_add_word_enrichment_support.sql) to be applied. It adds normalized lemma support, enrichment columns, and the `upsert_external_word` RPC used for safe new-word persistence.

If your remote database already contains schema objects from an earlier manual setup, you may need `supabase migration repair --linked --status applied <version>` before pushing. The dedicated Supabase notes live in [`supabase/README.md`](/Users/anthonyshadowitz/Desktop/WordApp/supabase/README.md).

## Running and testing
Run the app from Xcode with the `LinguaDaily` scheme, or run tests from the command line. Adjust the simulator destination if needed for your machine.

```bash
xcodebuild -scheme LinguaDaily -project /Users/anthonyshadowitz/Desktop/WordApp/LinguaDaily.xcodeproj -destination 'platform=iOS Simulator,OS=26.3.1,name=iPhone 17' test
```

The current suite covers auth, onboarding, notifications, profile, settings, daily lesson, word detail, review, archive, progress, translate flows, analytics/crash wiring, subscriptions, domain logic, and the new enrichment clients/coordinator/cache/persistence paths.

## Provider status
Integrated app-side now:
- Supabase
- Wiktionary
- Forvo
- Google Cloud Text-to-Speech
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
