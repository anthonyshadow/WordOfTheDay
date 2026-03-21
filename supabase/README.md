# Supabase Setup

## Apply migrations
1. Create or open the Supabase project.
2. Install dependencies with `npm install`.
3. Log in with `npm run db:login`.
4. Link the repo with `npm run db:link`.
5. Run `npm run db:push`.
6. Verify RLS is enabled for all user tables.

## Seed content included
- French language entry
- 20 words
- Native + slow pronunciation metadata for each word
- 2 example sentences per word

## Notes
- `users` references `auth.users` and mirrors app identity.
- `profiles` stores onboarding and streak metadata.
- `user_word_progress` + `review_queue` power spaced review.
