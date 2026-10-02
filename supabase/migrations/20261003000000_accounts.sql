-- Accounts: farmer profiles and moving a phone's anonymous data onto the
-- email account the farmer signs in with.
--
-- Each phone starts with an anonymous account (so it can sync before anyone
-- signs in). When the farmer signs in by email, the phone may land on a brand
-- new account or on one that already exists (e.g. a new phone). Either way,
-- its anonymous scans and plan are moved to that account:
--
--   1. while still anonymous:  ticket := start_account_merge()
--   2. sign in with the email code
--   3. as the email account:   finish_account_merge(ticket)
--
-- The ticket is a single-use secret that only the phone holding the
-- anonymous session can obtain, and it expires after an hour.

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id            uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  display_name  text check (char_length(display_name) <= 80),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;

create policy "Users can read their own profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

create policy "Users can create their own profile"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);

create policy "Users can update their own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- ---------------------------------------------------------------------------
-- account merges (private schema: not reachable through the API)
-- ---------------------------------------------------------------------------
create schema if not exists private;

create table private.account_merges (
  ticket      uuid primary key default gen_random_uuid(),
  from_user   uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

create function public.start_account_merge()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  new_ticket uuid;
begin
  if uid is null then
    raise exception 'Not signed in';
  end if;
  if not coalesce((select u.is_anonymous from auth.users u where u.id = uid), false) then
    raise exception 'Only an anonymous account can be merged';
  end if;

  delete from private.account_merges m
  where m.from_user = uid or m.created_at < now() - interval '1 hour';

  insert into private.account_merges (from_user)
  values (uid)
  returning ticket into new_ticket;
  return new_ticket;
end;
$$;

create function public.finish_account_merge(merge_ticket uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  dst uuid := auth.uid();
  src uuid;
begin
  if dst is null then
    raise exception 'Not signed in';
  end if;

  delete from private.account_merges m
  where m.ticket = merge_ticket
    and m.created_at > now() - interval '1 hour'
  returning m.from_user into src;

  if src is null then
    raise exception 'Invalid or expired merge ticket';
  end if;
  if src = dst then
    return;
  end if;
  if not coalesce((select u.is_anonymous from auth.users u where u.id = src), false) then
    raise exception 'Only an anonymous account can be merged';
  end if;

  -- Scans: skip any the account already has (same phone, same moment), move the rest.
  delete from public.scans s
  where s.user_id = src
    and exists (
      select 1 from public.scans d
      where d.user_id = dst and d.taken_at = s.taken_at
    );
  update public.scans set user_id = dst where user_id = src;

  -- Plan: an account keeps its own plan; otherwise it takes the phone's.
  if exists (select 1 from public.crop_plans p where p.user_id = dst) then
    delete from public.crop_plans where user_id = src;
  else
    update public.crop_plans set user_id = dst where user_id = src;
  end if;
end;
$$;

revoke execute on function public.start_account_merge() from public, anon;
revoke execute on function public.finish_account_merge(uuid) from public, anon;
grant execute on function public.start_account_merge() to authenticated;
grant execute on function public.finish_account_merge(uuid) to authenticated;
