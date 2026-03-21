# Supabase Setup

## Apply migrations
1. Create a Supabase project.
2. Run SQL migrations in order:
   - `20260308130000_initial_schema.sql`
   - `20260308131000_seed_french.sql`
3. Verify RLS is enabled for all user tables.

## Seed content included
- French language entry
- 20 words
- Native + slow pronunciation metadata for each word
- 2 example sentences per word

## Notes
- `users` references `auth.users` and mirrors app identity.
- `profiles` stores onboarding and streak metadata.
- `user_word_progress` + `review_queue` power spaced review.
