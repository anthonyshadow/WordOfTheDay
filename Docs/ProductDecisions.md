# LinguaDaily V1 Product/Technical Decisions

## Review Interval Logic (V1)
`user_word_progress.current_interval_days` progression on correct review:
- Stage 0 (just learned): 1 day
- Stage 1: 3 days
- Stage 2: 7 days
- Stage 3: 14 days
- Stage 4+: 30 days recurring

Incorrect answer behavior:
- Set next interval to 1 day
- Increment review attempts
- Keep word as `review_due` until next successful cycle

Mastery rule:
- Word becomes `mastered` after 4 consecutive correct reviews (reaching 14-day stage) and at least 5 total attempts.

## Word Status Model
- `new`: assigned but not marked learned.
- `learned`: user marked learned; may or may not be due.
- `review_due`: `next_review_at <= now` for learned word.
- `mastered`: long-interval stable word.
- `favorited` is a boolean overlay, not a separate lifecycle status.

## Free vs Premium (V1)
Free:
- 1 active language
- 1 daily word
- archive limited to most recent 30 learned words
- review queue up to 20 due cards/day

Premium:
- unlimited archive
- unlimited daily review queue
- slow pronunciation mode flag (UI-ready)
- themed word packs metadata flag (content-ready)

## Cache Strategy
- Cache only:
  - today lesson payload
  - archive metadata rows
- Keep cache lightweight and replace records by `updated_at`.

## Offline Behavior
- Today view: show last fetched lesson for same day if available.
- Archive: show cached rows + stale label.
- Review: can attempt cached cards; answer submit currently requires network in this scaffold.

## Notification Strategy
- Store preference and reminder time locally and remotely.
- Use local notifications during development.
- Deep links route to:
  - `linguadaily://today`
  - `linguadaily://review`

## Error Handling
- `AppError` categories:
  - network
  - auth
  - decoding
  - validation
  - unknown
- Present concise end-user messaging.
- Detailed context logged to crash reporter.

## Loading Patterns
- Initial screen load: full-width skeleton card.
- Section refresh: inline spinner.
- Empty results: neutral card with suggested next action.

## Ambiguity Resolutions
- Daily assignment happens lazily on first app open each day via RPC/service call.
- Review queue contains meaning recall multiple-choice only in v1.
- Share action is placeholder `ShareLink`/sheet wrapper with generated text.
