create type public.translation_input_mode as enum (
  'text',
  'voice',
  'camera'
);

create table public.translations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  input_mode public.translation_input_mode not null,
  source_text text not null,
  translated_text text not null,
  source_language text not null,
  target_language text not null,
  is_saved boolean not null default true,
  is_favorited boolean not null default false,
  transcription_text text,
  extracted_text text,
  source_image_url text,
  detection_confidence double precision,
  session_id text,
  provider_metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint translations_favorite_requires_saved check (not is_favorited or is_saved)
);

create index idx_translations_user_created
  on public.translations(user_id, created_at desc);

create index idx_translations_user_favorites
  on public.translations(user_id, is_favorited)
  where is_saved = true;

create index idx_translations_search on public.translations using gin (
  to_tsvector('simple', coalesce(source_text, '') || ' ' || coalesce(translated_text, ''))
);

create trigger translations_set_updated_at
before update on public.translations
for each row execute function public.set_updated_at();

alter table public.translations enable row level security;

create policy "translations_own_rows"
  on public.translations
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
