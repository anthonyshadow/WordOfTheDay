alter table public.profiles
  add column if not exists preferred_accent text,
  add column if not exists daily_learning_mode text not null default 'balanced',
  add column if not exists appearance text not null default 'system';

alter table public.profiles
  drop constraint if exists profiles_daily_learning_mode_check;

alter table public.profiles
  add constraint profiles_daily_learning_mode_check
  check (daily_learning_mode in ('balanced', 'review_focus', 'daily_word_only'));

alter table public.profiles
  drop constraint if exists profiles_appearance_check;

alter table public.profiles
  add constraint profiles_appearance_check
  check (appearance in ('system', 'light', 'dark'));

update public.profiles as profiles
set preferred_accent = accents.accent
from (
  select distinct on (words.language_id)
    words.language_id,
    word_audio.accent
  from public.words
  join public.word_audio
    on word_audio.word_id = words.id
  where btrim(coalesce(word_audio.accent, '')) <> ''
  order by words.language_id, word_audio.accent
) as accents
where profiles.active_language_id = accents.language_id
  and btrim(coalesce(profiles.preferred_accent, '')) = '';

create or replace function public.calculate_assignment_streaks(
  p_user_id uuid,
  p_reference_date date default current_date
)
returns table(current_streak integer, best_streak integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  assignment_dates date[];
  current_run integer := 0;
  best_run integer := 0;
  running integer := 0;
  last_assignment date;
  total_dates integer := 0;
begin
  select array_agg(assignment_date order by assignment_date)
  into assignment_dates
  from public.daily_word_assignments
  where user_id = p_user_id;

  total_dates := coalesce(array_length(assignment_dates, 1), 0);
  if total_dates = 0 then
    return query select 0, 0;
    return;
  end if;

  last_assignment := assignment_dates[total_dates];

  for i in 1..total_dates loop
    if i = 1 then
      running := 1;
    elsif assignment_dates[i] = assignment_dates[i - 1] + 1 then
      running := running + 1;
    else
      best_run := greatest(best_run, running);
      running := 1;
    end if;
  end loop;

  best_run := greatest(best_run, running);

  if last_assignment < p_reference_date - 1 then
    current_run := 0;
  else
    current_run := 1;
    if total_dates > 1 then
      for i in reverse 2..total_dates loop
        if assignment_dates[i] = assignment_dates[i - 1] + 1 then
          current_run := current_run + 1;
        else
          exit;
        end if;
      end loop;
    end if;
  end if;

  return query select current_run, greatest(best_run, current_run);
end;
$$;

create or replace function public.refresh_profile_streaks(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  streaks record;
begin
  select * into streaks
  from public.calculate_assignment_streaks(p_user_id);

  update public.profiles
  set
    streak_current = coalesce(streaks.current_streak, 0),
    streak_best = greatest(coalesce(streaks.best_streak, 0), coalesce(streaks.current_streak, 0))
  where id = p_user_id;
end;
$$;

create or replace function public.on_daily_word_assignment_streak_refresh()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_profile_streaks(old.user_id);
    return old;
  end if;

  perform public.refresh_profile_streaks(new.user_id);
  return new;
end;
$$;

drop trigger if exists daily_word_assignments_refresh_profile_streaks
on public.daily_word_assignments;

create trigger daily_word_assignments_refresh_profile_streaks
after insert or delete on public.daily_word_assignments
for each row execute function public.on_daily_word_assignment_streak_refresh();

do $$
declare
  profile_row record;
begin
  for profile_row in select id from public.profiles loop
    perform public.refresh_profile_streaks(profile_row.id);
  end loop;
end;
$$;

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from auth.users
  where id = auth.uid();
end;
$$;

revoke all on function public.delete_account() from public;
grant execute on function public.delete_account() to authenticated;
