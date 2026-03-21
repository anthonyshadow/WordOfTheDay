# Analytics Event Contract (PostHog)

All events are defined in code (`AnalyticsEvent`) to avoid stringly-typed usage.

## Required Product Spec Events
- `onboarding_started`
- `onboarding_completed`
- `language_selected`
- `reminder_time_set`
- `notification_permission_granted`
- `signup_completed`
- `paywall_viewed`
- `subscription_started`
- `daily_word_opened`
- `pronunciation_played`
- `word_marked_learned`
- `word_favorited`
- `review_started`
- `review_completed`
- `archive_searched`
- `push_opened`
- `streak_extended`

## Additional Operational Events
- `app_opened`
- `session_restored`
- `auth_view_opened`
- `auth_email_signup_tapped`
- `auth_email_login_tapped`
- `auth_apple_tapped`
- `auth_google_tapped`
- `auth_success`
- `auth_failed`
- `today_loaded`
- `daily_word_play_pronunciation`
- `daily_word_marked_learned`
- `daily_word_favorited`
- `daily_word_saved_for_review`
- `daily_word_share_tapped`
- `word_detail_opened`
- `review_opened`
- `review_answer_submitted`
- `review_answer_correct`
- `review_answer_incorrect`
- `review_queue_empty`
- `archive_opened`
- `archive_filter_changed`
- `archive_sort_changed`
- `archive_word_opened`
- `progress_opened`
- `profile_opened`
- `settings_opened`
- `notifications_education_viewed`
- `notifications_permission_requested`
- `notifications_permission_result`
- `paywall_opened`
- `paywall_plan_selected`
- `purchase_started`
- `purchase_success`
- `purchase_failed`
- `restore_purchases_tapped`
