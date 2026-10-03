-- Phone sign-in: farmers can get their sign-in code by SMS. Supabase Auth
-- calls the "Send SMS" hook (supabase/functions/send-sms), which sends the
-- code with Africa's Talking. Every SMS costs money, so before sending, the
-- hook asks sms_allow() whether this number, and the whole app, are still
-- within their limits.

-- ---------------------------------------------------------------------------
-- sms_log: one row per sign-in SMS, kept for 7 days. Only the hook (with the
-- service role key) can use it; the app has no access.
-- ---------------------------------------------------------------------------
create table public.sms_log (
  id       bigint generated always as identity primary key,
  phone    text not null,              -- digits only, e.g. '256772123456'
  sent_at  timestamptz not null default now()
);

create index sms_log_phone_sent_at_idx on public.sms_log (phone, sent_at);
create index sms_log_sent_at_idx on public.sms_log (sent_at);

alter table public.sms_log enable row level security;
-- No policies: anon and authenticated users can't read or write it.
revoke all on public.sms_log from anon, authenticated;

-- ---------------------------------------------------------------------------
-- sms_allow: records an SMS about to be sent to p_phone and returns 'ok', or
-- returns why it must not be sent:
--   'phone_limit' - this number already got p_per_hour codes in the last hour
--   'daily_limit' - the app already sent p_per_day codes today (cost cap)
-- The advisory lock makes concurrent requests count correctly.
-- ---------------------------------------------------------------------------
create or replace function public.sms_allow(
  p_phone     text,
  p_per_hour  int default 5,
  p_per_day   int default 500
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  digits text := regexp_replace(p_phone, '\D', '', 'g');
begin
  perform pg_advisory_xact_lock(hashtext('sms_allow'));

  if (select count(*) from public.sms_log
      where phone = digits and sent_at > now() - interval '1 hour') >= p_per_hour then
    return 'phone_limit';
  end if;

  if (select count(*) from public.sms_log
      where sent_at > now() - interval '1 day') >= p_per_day then
    return 'daily_limit';
  end if;

  insert into public.sms_log (phone) values (digits);
  -- Keep a week only.
  delete from public.sms_log where sent_at < now() - interval '7 days';
  return 'ok';
end;
$$;

revoke execute on function public.sms_allow(text, int, int) from public, anon, authenticated;
grant execute on function public.sms_allow(text, int, int) to service_role;
