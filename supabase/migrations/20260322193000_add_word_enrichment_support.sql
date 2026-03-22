create or replace function public.normalize_word_lemma(input text)
returns text
language sql
immutable
as $$
  select lower(
    regexp_replace(
      replace(btrim(coalesce(input, '')), '’', ''''),
      '\s+',
      ' ',
      'g'
    )
  );
$$;

alter table public.words
  add column if not exists pronunciation_guidance text,
  add column if not exists language_variant text,
  add column if not exists enrichment_source text,
  add column if not exists enrichment_updated_at timestamptz;

alter table public.words
  add column if not exists normalized_lemma text
  generated always as (public.normalize_word_lemma(lemma)) stored;

create unique index if not exists idx_words_language_normalized_lemma
  on public.words(language_id, normalized_lemma);

alter table public.word_audio
  add column if not exists source text,
  add column if not exists speaker_label text,
  add column if not exists provider_reference text;

update public.word_audio
set source = 'supabase'
where source is null;

alter table public.word_audio
  alter column source set default 'supabase';

alter table public.example_sentences
  add column if not exists source text;

update public.example_sentences
set source = 'supabase'
where source is null;

create or replace function public.upsert_external_word(
  p_language_code text,
  p_lemma text,
  p_transliteration text default null,
  p_pronunciation_ipa text default null,
  p_pronunciation_guidance text default null,
  p_part_of_speech text default null,
  p_cefr_level text default null,
  p_definition text default null,
  p_usage_notes text default null,
  p_language_variant text default null,
  p_enrichment_source text default null,
  p_examples jsonb default '[]'::jsonb,
  p_audio jsonb default '[]'::jsonb
)
returns table(word_id uuid, was_inserted boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_language_id uuid;
  v_word_id uuid;
  v_example jsonb;
  v_audio_item jsonb;
  v_example_index integer := 0;
  v_inserted boolean := false;
  v_source text;
begin
  if btrim(coalesce(p_language_code, '')) = '' then
    raise exception 'A language code is required.';
  end if;

  if btrim(coalesce(p_lemma, '')) = '' then
    raise exception 'A lemma is required.';
  end if;

  if btrim(coalesce(p_definition, '')) = '' then
    raise exception 'A definition is required.';
  end if;

  select id
  into v_language_id
  from public.languages
  where lower(code) = lower(btrim(p_language_code))
  limit 1;

  if v_language_id is null then
    raise exception 'Language not found for code %.', p_language_code;
  end if;

  select id
  into v_word_id
  from public.words
  where language_id = v_language_id
    and normalized_lemma = public.normalize_word_lemma(p_lemma)
  limit 1;

  if v_word_id is null then
    insert into public.words (
      language_id,
      lemma,
      transliteration,
      pronunciation_ipa,
      pronunciation_guidance,
      part_of_speech,
      cefr_level,
      definition,
      usage_notes,
      language_variant,
      enrichment_source,
      enrichment_updated_at
    )
    values (
      v_language_id,
      btrim(p_lemma),
      nullif(btrim(coalesce(p_transliteration, '')), ''),
      nullif(btrim(coalesce(p_pronunciation_ipa, '')), ''),
      nullif(btrim(coalesce(p_pronunciation_guidance, '')), ''),
      nullif(btrim(coalesce(p_part_of_speech, '')), ''),
      nullif(btrim(coalesce(p_cefr_level, '')), ''),
      btrim(p_definition),
      nullif(btrim(coalesce(p_usage_notes, '')), ''),
      nullif(btrim(coalesce(p_language_variant, '')), ''),
      nullif(btrim(coalesce(p_enrichment_source, '')), ''),
      now()
    )
    returning id into v_word_id;

    v_inserted := true;
  end if;

  if v_inserted then
    for v_example in
      select value
      from jsonb_array_elements(coalesce(p_examples, '[]'::jsonb))
    loop
      exit when v_example_index >= 3;

      if btrim(coalesce(v_example ->> 'sentence', '')) = '' then
        continue;
      end if;

      v_example_index := v_example_index + 1;
      v_source := nullif(
        btrim(coalesce(v_example ->> 'source', coalesce(p_enrichment_source, 'external'))),
        ''
      );

      insert into public.example_sentences (
        word_id,
        sentence,
        translation,
        order_index,
        source
      )
      values (
        v_word_id,
        btrim(v_example ->> 'sentence'),
        coalesce(v_example ->> 'translation', ''),
        v_example_index,
        v_source
      )
      on conflict (word_id, order_index) do nothing;
    end loop;

    for v_audio_item in
      select value
      from jsonb_array_elements(coalesce(p_audio, '[]'::jsonb))
    loop
      if btrim(coalesce(v_audio_item ->> 'audio_url', '')) = '' then
        continue;
      end if;

      insert into public.word_audio (
        word_id,
        accent,
        speed,
        audio_url,
        duration_ms,
        source,
        speaker_label,
        provider_reference
      )
      values (
        v_word_id,
        coalesce(nullif(btrim(v_audio_item ->> 'accent'), ''), 'standard'),
        coalesce(nullif(btrim(v_audio_item ->> 'speed'), ''), 'native'),
        btrim(v_audio_item ->> 'audio_url'),
        nullif(v_audio_item ->> 'duration_ms', '')::integer,
        coalesce(nullif(btrim(v_audio_item ->> 'source'), ''), coalesce(p_enrichment_source, 'external')),
        nullif(btrim(v_audio_item ->> 'speaker_label'), ''),
        nullif(btrim(v_audio_item ->> 'provider_reference'), '')
      )
      on conflict (word_id, accent, speed) do nothing;
    end loop;
  end if;

  return query select v_word_id, v_inserted;
end;
$$;

grant execute on function public.upsert_external_word(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  jsonb,
  jsonb
) to authenticated;
