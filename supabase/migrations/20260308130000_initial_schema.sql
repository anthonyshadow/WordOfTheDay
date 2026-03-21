-- LinguaDaily V1 initial schema

create extension if not exists pgcrypto;

create type public.learning_goal as enum (
  'travel',
  'work',
  'school',
  'culture',
  'family'
);

create type public.learning_level as enum (
  'beginner',
  'intermediate',
  'advanced'
);

create type public.user_word_status as enum (
  'new',
  'learned',
  'review_due',
  'mastered'
);

create type public.review_queue_state as enum (
  'queued',
  'completed',
  'skipped'
);

create type public.subscription_plan as enum (
  'free',
  'premium_monthly',
  'premium_yearly'
);

create type public.subscription_status as enum (
  'active',
  'trialing',
  'expired',
  'canceled'
);

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.languages (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  native_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references public.users(id) on delete cascade,
  email text not null,
  display_name text,
  learning_goal public.learning_goal,
  active_language_id uuid references public.languages(id),
  level public.learning_level,
  reminder_time time,
  timezone text,
  onboarding_completed_at timestamptz,
  streak_current integer not null default 0 check (streak_current >= 0),
  streak_best integer not null default 0 check (streak_best >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.words (
  id uuid primary key default gen_random_uuid(),
  language_id uuid not null references public.languages(id) on delete cascade,
  lemma text not null,
  transliteration text,
  pronunciation_ipa text,
  part_of_speech text,
  cefr_level text,
  frequency_rank integer check (frequency_rank > 0),
  definition text not null,
  usage_notes text,
  created_at timestamptz not null default now(),
  unique(language_id, lemma)
);

create table public.word_audio (
  id uuid primary key default gen_random_uuid(),
  word_id uuid not null references public.words(id) on delete cascade,
  accent text not null,
  speed text not null,
  audio_url text not null,
  duration_ms integer,
  created_at timestamptz not null default now(),
  unique(word_id, accent, speed)
);

create table public.example_sentences (
  id uuid primary key default gen_random_uuid(),
  word_id uuid not null references public.words(id) on delete cascade,
  sentence text not null,
  translation text not null,
  order_index integer not null check (order_index between 1 and 3),
  created_at timestamptz not null default now(),
  unique(word_id, order_index)
);

create table public.daily_word_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  word_id uuid not null references public.words(id) on delete cascade,
  assignment_date date not null,
  source text not null default 'algorithm_v1',
  created_at timestamptz not null default now(),
  unique(user_id, assignment_date),
  unique(user_id, word_id)
);

create table public.user_word_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  word_id uuid not null references public.words(id) on delete cascade,
  status public.user_word_status not null default 'new',
  is_favorited boolean not null default false,
  is_saved_for_review boolean not null default false,
  consecutive_correct integer not null default 0 check (consecutive_correct >= 0),
  total_reviews integer not null default 0 check (total_reviews >= 0),
  correct_reviews integer not null default 0 check (correct_reviews >= 0),
  current_interval_days integer not null default 0 check (current_interval_days >= 0),
  next_review_at timestamptz,
  learned_at timestamptz,
  last_reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, word_id)
);

create table public.review_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  word_id uuid not null references public.words(id) on delete cascade,
  due_at timestamptz not null,
  state public.review_queue_state not null default 'queued',
  last_outcome_correct boolean,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  selected_option text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index review_queue_unique_active
  on public.review_queue(user_id, word_id)
  where state = 'queued';

create table public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  is_enabled boolean not null default false,
  reminder_time time not null default '08:00:00',
  timezone text not null default 'UTC',
  push_token text,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  provider text not null default 'revenuecat',
  plan public.subscription_plan not null default 'free',
  status public.subscription_status not null default 'active',
  entitlement_expires_at timestamptz,
  current_period_end timestamptz,
  original_transaction_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_words_language on public.words(language_id);
create index idx_words_frequency on public.words(language_id, frequency_rank);
create index idx_assignments_user_date on public.daily_word_assignments(user_id, assignment_date desc);
create index idx_progress_user_status on public.user_word_progress(user_id, status);
create index idx_progress_next_review on public.user_word_progress(user_id, next_review_at);
create index idx_review_queue_due on public.review_queue(user_id, due_at) where state = 'queued';
create index idx_example_word on public.example_sentences(word_id);

create index idx_words_search on public.words using gin (
  to_tsvector('simple', coalesce(lemma, '') || ' ' || coalesce(definition, '') || ' ' || coalesce(usage_notes, ''))
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger user_word_progress_set_updated_at
before update on public.user_word_progress
for each row execute function public.set_updated_at();

create trigger review_queue_set_updated_at
before update on public.review_queue
for each row execute function public.set_updated_at();

create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

create trigger subscriptions_set_updated_at
before update on public.subscriptions
for each row execute function public.set_updated_at();

alter table public.users enable row level security;
alter table public.profiles enable row level security;
alter table public.languages enable row level security;
alter table public.words enable row level security;
alter table public.word_audio enable row level security;
alter table public.example_sentences enable row level security;
alter table public.daily_word_assignments enable row level security;
alter table public.user_word_progress enable row level security;
alter table public.review_queue enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.subscriptions enable row level security;

create policy "users_own_row"
  on public.users
  for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "profiles_own_row"
  on public.profiles
  for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "languages_read_all"
  on public.languages
  for select
  using (true);

create policy "words_read_all"
  on public.words
  for select
  using (true);

create policy "word_audio_read_all"
  on public.word_audio
  for select
  using (true);

create policy "example_sentences_read_all"
  on public.example_sentences
  for select
  using (true);

create policy "assignments_own_rows"
  on public.daily_word_assignments
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "progress_own_rows"
  on public.user_word_progress
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "review_queue_own_rows"
  on public.review_queue
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "notification_preferences_own_rows"
  on public.notification_preferences
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "subscriptions_own_rows"
  on public.subscriptions
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
