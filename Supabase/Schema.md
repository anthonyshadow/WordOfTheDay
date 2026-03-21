# Supabase Schema Overview

## Tables

### `users`
- PK: `id` (uuid, references `auth.users.id`)
- Fields: `created_at`
- RLS: owner full access (`auth.uid() = id`)

### `profiles`
- PK: `id` (uuid, references `users.id`)
- FK: `active_language_id -> languages.id`
- Fields: email, display_name, learning_goal, level, reminder_time, timezone, streaks, onboarding timestamps
- Indexes: PK only
- Constraints: non-negative streaks
- RLS: owner full access

### `languages`
- PK: `id` (uuid)
- Unique: `code`
- Fields: code, name, native_name, is_active, created_at
- RLS: read for all authenticated users

### `words`
- PK: `id` (uuid)
- FK: `language_id -> languages.id`
- Unique: `(language_id, lemma)`
- Fields: transliteration, IPA, part_of_speech, cefr_level, frequency_rank, definition, usage_notes
- Indexes:
  - `idx_words_language`
  - `idx_words_frequency`
  - `idx_words_search` (GIN full-text)
- Constraints: frequency rank positive
- RLS: read for all authenticated users

### `word_audio`
- PK: `id` (uuid)
- FK: `word_id -> words.id`
- Unique: `(word_id, accent, speed)`
- Fields: accent, speed, audio_url, duration_ms
- RLS: read for all authenticated users

### `example_sentences`
- PK: `id` (uuid)
- FK: `word_id -> words.id`
- Unique: `(word_id, order_index)`
- Fields: sentence, translation, order_index
- Indexes: `idx_example_word`
- Constraints: order index between 1 and 3
- RLS: read for all authenticated users

### `daily_word_assignments`
- PK: `id` (uuid)
- FK: `user_id -> users.id`, `word_id -> words.id`
- Unique: `(user_id, assignment_date)`, `(user_id, word_id)`
- Fields: assignment_date, source, created_at
- Indexes: `idx_assignments_user_date`
- RLS: owner full access

### `user_word_progress`
- PK: `id` (uuid)
- FK: `user_id -> users.id`, `word_id -> words.id`
- Unique: `(user_id, word_id)`
- Fields: status, favorite/review flags, counters, intervals, review timestamps
- Indexes:
  - `idx_progress_user_status`
  - `idx_progress_next_review`
- Constraints: non-negative counters/interval
- RLS: owner full access

### `review_queue`
- PK: `id` (uuid)
- FK: `user_id -> users.id`, `word_id -> words.id`
- Fields: due_at, state, attempt_count, last_outcome_correct, selected_option
- Indexes:
  - `review_queue_unique_active` partial unique (`state='queued'`)
  - `idx_review_queue_due` partial index (`state='queued'`)
- Constraints: non-negative attempts
- RLS: owner full access

### `notification_preferences`
- PK: `id` (uuid)
- FK: `user_id -> users.id`
- Unique: `user_id`
- Fields: is_enabled, reminder_time, timezone, push_token, created_at, updated_at
- RLS: owner full access

### `subscriptions`
- PK: `id` (uuid)
- FK: `user_id -> users.id`
- Unique: `user_id`
- Fields: provider, plan, status, entitlement_expiry, period_end, transaction_id
- RLS: owner full access

## Seed Content
- 1 language: French
- 20 words
- 2 example sentences per word
- native + slow pronunciation metadata for each word
