create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mood_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  mood_score smallint not null check (mood_score between 1 and 5),
  feelings text[] not null default '{}',
  note text not null default '',
  recorded_at timestamptz not null default now()
);

create index mood_checkins_user_recorded_idx
  on public.mood_checkins (user_id, recorded_at desc);

create table public.phq9_assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  total_score smallint not null check (total_score between 0 and 27),
  responses jsonb not null
    check (jsonb_typeof(responses) = 'array' and jsonb_array_length(responses) = 9),
  completed_at timestamptz not null default now()
);

create index phq9_assessments_user_completed_idx
  on public.phq9_assessments (user_id, completed_at desc);

create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 5000),
  created_at timestamptz not null default now()
);

create index journal_entries_user_created_idx
  on public.journal_entries (user_id, created_at desc);

create table public.in_app_notices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  message text not null check (char_length(message) between 1 and 500),
  created_at timestamptz not null default now()
);

create index in_app_notices_user_created_idx
  on public.in_app_notices (user_id, created_at desc);

create table public.goal_completions (
  user_id uuid not null references auth.users (id) on delete cascade,
  goal_id text not null,
  completed_on date not null default current_date,
  created_at timestamptz not null default now(),
  primary key (user_id, goal_id, completed_on)
);

create table public.notification_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  notifications_enabled boolean not null default true,
  daily_reminder_enabled boolean not null default true,
  reminder_time text not null default '9:00 AM',
  updated_at timestamptz not null default now()
);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

create function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', '')
  )
  on conflict (id) do update
    set display_name = excluded.display_name;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.create_profile_for_new_user();

alter table public.profiles enable row level security;
alter table public.mood_checkins enable row level security;
alter table public.phq9_assessments enable row level security;
alter table public.journal_entries enable row level security;
alter table public.in_app_notices enable row level security;
alter table public.goal_completions enable row level security;
alter table public.notification_preferences enable row level security;

create policy "Users manage their own profile"
on public.profiles for all to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "Users manage their own mood check-ins"
on public.mood_checkins for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users manage their own assessments"
on public.phq9_assessments for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users manage their own journal entries"
on public.journal_entries for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users manage their own in-app notices"
on public.in_app_notices for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users manage their own goal completions"
on public.goal_completions for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users manage their own notification preferences"
on public.notification_preferences for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

grant select, insert, update, delete on
  public.profiles,
  public.mood_checkins,
  public.phq9_assessments,
  public.journal_entries,
  public.in_app_notices,
  public.goal_completions,
  public.notification_preferences
to authenticated;
