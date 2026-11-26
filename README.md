# MoodCare

MoodCare is a responsive Flutter mental wellbeing companion with daily mood
check-ins, a PHQ-9-inspired reflection screen, self-care tools, goals, a journal,
progress views, reminders, and support resources. Screen transitions, buttons,
cards, mood selection, charts, and the breathing exercise use subtle motion.

MoodCare is not a medical device and does not provide clinical diagnosis or
treatment. Assessment results are screening reflections, not diagnoses.
Reminder preferences are saved, but operating-system notifications are not
configured.

## Run locally

```sh
flutter pub get
flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PROJECT_PUBLISHABLE_KEY
```

The project URL defaults to `https://midbconiifjjqphjgcuj.supabase.co` and can
be overridden with `--dart-define=SUPABASE_URL=...`. The legacy
`SUPABASE_ANON_KEY` define is also accepted. Only use a publishable (anon) key
in the Flutter client; never include a Supabase `service_role` key. Without a
key, the app opens in demo mode and does not create remote accounts.

## Set up the database

The schema and row-level security policies are in
`supabase/migrations/20261118000000_moodcare_schema.sql`. Apply them to project
`midbconiifjjqphjgcuj` with the Supabase CLI:

```sh
supabase login
supabase link --project-ref midbconiifjjqphjgcuj
supabase db push
```

Or paste the migration into the project's Supabase SQL Editor. The migration
creates private per-user profile, mood check-in, PHQ-9 response, journal,
in-app notice, goal, and reminder-preference tables with RLS enabled. It must be applied by an
authorized project owner before cloud auth/data features can work.
The migration has been prepared locally; this workspace has no Supabase CLI
login or project credentials, so it has not been applied to the live project.

## Verify

```sh
flutter analyze
flutter test
flutter build web
```
