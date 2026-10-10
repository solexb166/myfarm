-- Account deletion from the app (Account -> Delete account), required by
-- Google Play. The app first removes the farmer's photos through the Storage
-- API (the storage policies let them delete their own folder), then calls
-- delete_my_account(), which deletes their login. Scans, the season plan and
-- the profile go with it (on delete cascade).

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;
  -- Their number in the SMS rate-limit log, if they signed in by phone.
  delete from public.sms_log
  where phone = (
    select regexp_replace(coalesce(u.phone, ''), '\D', '', 'g')
    from auth.users u where u.id = uid
  );
  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
