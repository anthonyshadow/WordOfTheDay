# Testing Strategy

## Unit tests in scope
- `ReviewScheduler`: interval progression, incorrect reset, mastery threshold.
- `DailyWordAssigner`: deterministic assignment, fallback behavior.
- `AccessPolicy`: free-tier archive cap and premium unlimited behavior.
- `AppState`: auth/onboarding derived state, deep-link tab routing, navigation reset.
- `AuthViewModel`: email validation, login/signup success paths, analytics, failure mapping.
- `ReviewViewModel`: queue loading, progress label, answer submission, completion state.
- `SettingsViewModel`: preference loading, reminder scheduling, logout navigation reset.

## UI/Integration test plan (next)
- Onboarding step progression + persistence.
- Today screen fallback to cached lesson.
- Review answer submission feedback states.
- Archive search/filter/sort combinations.
- Deep link routing from URL + notification payload.

## Contract tests (next)
- Supabase response decoding for typed models.
- RLS policy smoke tests in staging project.
