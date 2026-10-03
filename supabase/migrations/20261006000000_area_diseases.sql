-- Diseases near you: which diseases farmers are finding in a district.
--
-- Farmers can only read their own scans (RLS), so these functions run as
-- the owner and return totals only - never who, never exact places. A
-- disease is only listed once at least 3 different farmers found it in the
-- district, so a single farm can't be picked out. Signed-in users only.

-- Diseases found in p_district in the last p_days (7 to 365), most widespread
-- first.
create or replace function public.area_diseases(
  p_district  text,
  p_days      int default 90
)
returns table (
  crop       text,
  label      text,
  farmers    bigint,
  scans      bigint,
  last_seen  date
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    s.crop,
    s.label,
    count(distinct s.user_id) as farmers,
    count(*) as scans,
    max(s.taken_at)::date as last_seen
  from public.scans s
  where s.district_id = p_district
    and not s.healthy
    and s.label is not null
    and s.taken_at > now() - make_interval(days => least(greatest(coalesce(p_days, 90), 7), 365))
  group by s.crop, s.label
  having count(distinct s.user_id) >= 3
  order by farmers desc, scans desc, s.label
  limit 20;
$$;

-- How many farmers scanned in p_district in the last p_days, healthy crops
-- included, so the app can say what the list is based on. Zero below 3.
create or replace function public.area_farmers(
  p_district  text,
  p_days      int default 90
)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select case when n >= 3 then n else 0 end
  from (
    select count(distinct s.user_id) as n
    from public.scans s
    where s.district_id = p_district
      and s.taken_at > now() - make_interval(days => least(greatest(coalesce(p_days, 90), 7), 365))
  ) t;
$$;

revoke execute on function public.area_diseases(text, int) from public, anon;
revoke execute on function public.area_farmers(text, int) from public, anon;
grant execute on function public.area_diseases(text, int) to authenticated;
grant execute on function public.area_farmers(text, int) to authenticated;
