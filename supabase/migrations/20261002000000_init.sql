-- MY FARM backend schema.
--
-- The app is offline-first: everything is stored on the phone first and
-- pushed here when there is a connection. Each phone signs in (anonymously
-- by default) and Row Level Security limits every user to their own rows.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- scans: one row per on-device diagnosis (backup + disease analytics)
-- ---------------------------------------------------------------------------
create table public.scans (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  taken_at    timestamptz not null,           -- when the photo was diagnosed on the phone
  crop        text not null,                  -- display name, e.g. 'Cassava'
  label       text,                           -- raw model class, e.g. 'cassava_mosaic_disease'
  diagnosis   text not null,                  -- pretty name shown to the farmer
  confidence  smallint not null check (confidence between 0 and 100),
  healthy     boolean not null,
  lang        text not null default 'en' check (lang in ('en', 'lg')),
  photo_path  text,                           -- object path in the 'scan-photos' bucket
  created_at  timestamptz not null default now(),
  -- The phone retries uploads, so (user, taken_at) makes them idempotent.
  unique (user_id, taken_at)
);

create index scans_label_taken_at_idx on public.scans (label, taken_at);

alter table public.scans enable row level security;

create policy "Users can read their own scans"
  on public.scans for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can add their own scans"
  on public.scans for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own scans"
  on public.scans for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own scans"
  on public.scans for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- crop_plans: the single active season plan per user
-- ---------------------------------------------------------------------------
create table public.crop_plans (
  user_id       uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  crop          text not null,
  region        text,
  summary       text not null default '',
  planted_date  date not null,
  tasks         jsonb not null default '[]'::jsonb,  -- list of CropTask JSON objects
  updated_at    timestamptz not null default now()
);

create trigger crop_plans_set_updated_at
  before update on public.crop_plans
  for each row execute function public.set_updated_at();

alter table public.crop_plans enable row level security;

create policy "Users can read their own plan"
  on public.crop_plans for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can add their own plan"
  on public.crop_plans for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own plan"
  on public.crop_plans for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own plan"
  on public.crop_plans for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- treatments: editable copy of lib/services/treatment_db.dart
--
-- The app ships with the bundled text and downloads this table when online;
-- a row here replaces the bundled text for that label + language. Edit rows
-- in the Supabase dashboard (Table Editor) - the app has read-only access.
-- ---------------------------------------------------------------------------
create table public.treatments (
  label       text not null,                  -- model class, or 'healthy'
  lang        text not null check (lang in ('en', 'lg')),
  cause       text not null,
  organic     text not null,
  chemical    text not null,
  prevent     text not null,
  updated_at  timestamptz not null default now(),
  primary key (label, lang)
);

create trigger treatments_set_updated_at
  before update on public.treatments
  for each row execute function public.set_updated_at();

alter table public.treatments enable row level security;

create policy "Anyone can read treatments"
  on public.treatments for select to anon, authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- disease_counts: weekly disease counts for analysis in the dashboard.
-- security_invoker makes it obey the scans RLS, and app users get no access.
-- ---------------------------------------------------------------------------
create view public.disease_counts
  with (security_invoker = on)
as
select
  date_trunc('week', taken_at)::date as week,
  crop,
  label,
  count(*) as scans,
  round(avg(confidence)) as avg_confidence
from public.scans
group by 1, 2, 3;

revoke all on public.disease_counts from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Storage: private bucket for scan photos, one folder per user (<uid>/...)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'scan-photos',
  'scan-photos',
  false,
  5242880, -- 5 MB; the app already resizes photos to 1600 px
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do nothing;

create policy "Users can upload their own scan photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'scan-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- select + update are needed for upsert (re-uploading after a failed sync).
create policy "Users can read their own scan photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'scan-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users can replace their own scan photos"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'scan-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'scan-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users can delete their own scan photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'scan-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
