-- Mirror new auth users into app-owned tables.

create or replace function public.handle_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  resolved_email text;
  resolved_display_name text;
  resolved_timezone text;
begin
  resolved_email := coalesce(
    nullif(new.email, ''),
    new.id::text || '@placeholder.local'
  );

  resolved_display_name := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(resolved_email, '@', 1), ''),
    'Learner'
  );

  resolved_timezone := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'timezone'), ''),
    'UTC'
  );

  insert into public.users (id)
  values (new.id)
  on conflict (id) do nothing;

  insert into public.profiles (id, email, display_name, timezone)
  values (new.id, resolved_email, resolved_display_name, resolved_timezone)
  on conflict (id) do update
    set email = excluded.email,
        display_name = coalesce(public.profiles.display_name, excluded.display_name),
        timezone = coalesce(public.profiles.timezone, excluded.timezone);

  insert into public.notification_preferences (user_id, timezone)
  values (new.id, resolved_timezone)
  on conflict (user_id) do nothing;

  insert into public.subscriptions (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_auth_user_created();

with auth_source as (
  select
    id,
    coalesce(nullif(email, ''), id::text || '@placeholder.local') as resolved_email,
    coalesce(
      nullif(btrim(raw_user_meta_data ->> 'display_name'), ''),
      nullif(btrim(raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(raw_user_meta_data ->> 'name'), ''),
      nullif(split_part(coalesce(nullif(email, ''), id::text || '@placeholder.local'), '@', 1), ''),
      'Learner'
    ) as resolved_display_name,
    coalesce(nullif(btrim(raw_user_meta_data ->> 'timezone'), ''), 'UTC') as resolved_timezone
  from auth.users
)
insert into public.users (id)
select id
from auth_source
on conflict (id) do nothing;

with auth_source as (
  select
    id,
    coalesce(nullif(email, ''), id::text || '@placeholder.local') as resolved_email,
    coalesce(
      nullif(btrim(raw_user_meta_data ->> 'display_name'), ''),
      nullif(btrim(raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(raw_user_meta_data ->> 'name'), ''),
      nullif(split_part(coalesce(nullif(email, ''), id::text || '@placeholder.local'), '@', 1), ''),
      'Learner'
    ) as resolved_display_name,
    coalesce(nullif(btrim(raw_user_meta_data ->> 'timezone'), ''), 'UTC') as resolved_timezone
  from auth.users
)
insert into public.profiles (id, email, display_name, timezone)
select id, resolved_email, resolved_display_name, resolved_timezone
from auth_source
on conflict (id) do update
  set email = excluded.email,
      display_name = coalesce(public.profiles.display_name, excluded.display_name),
      timezone = coalesce(public.profiles.timezone, excluded.timezone);

with auth_source as (
  select
    id,
    coalesce(nullif(btrim(raw_user_meta_data ->> 'timezone'), ''), 'UTC') as resolved_timezone
  from auth.users
)
insert into public.notification_preferences (user_id, timezone)
select id, resolved_timezone
from auth_source
on conflict (user_id) do nothing;

insert into public.subscriptions (user_id)
select id
from auth.users
on conflict (user_id) do nothing;
