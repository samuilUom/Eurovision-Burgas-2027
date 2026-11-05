-- Eurovision Burgas 2027: additive migration for the EXISTING Supabase project.
-- Does not change toilets, reviews, accounts or existing favorites.
-- Run this entire file once in Supabase SQL Editor; safe to run again.
begin;

create table if not exists public.city_places (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete cascade,
  category text not null check (category in ('restaurants','atms','shopping','hospitals','pharmacies','fuel','charging','transport')),
  name text not null check (char_length(btrim(name)) between 1 and 200),
  address text not null default '' check (char_length(address) <= 500),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  website text check (website is null or (char_length(website) <= 2048 and website ~* '^https?://[^[:space:]]+$')),
  notes text not null default '' check (char_length(notes) <= 2000),
  is_nonstop boolean,
  created_at timestamptz not null default now(),
  constraint nonstop_shops_only check (category in ('shopping','pharmacies','fuel','charging') or is_nonstop is null)
);
create index if not exists city_places_category_idx on public.city_places(category);
create index if not exists city_places_author_idx on public.city_places(created_by);
alter table public.city_places enable row level security;
revoke all on public.city_places from public, anon, authenticated;
grant select on public.city_places to anon, authenticated;
grant insert (id,created_by,category,name,address,latitude,longitude,website,notes,is_nonstop)
  on public.city_places to authenticated;
grant update (category,name,address,latitude,longitude,website,notes,is_nonstop), delete
  on public.city_places to authenticated;

drop policy if exists city_places_read on public.city_places;
create policy city_places_read on public.city_places for select to anon, authenticated using (true);
drop policy if exists city_places_add on public.city_places;
create policy city_places_add on public.city_places for insert to authenticated
  with check (created_by = (select auth.uid()));
drop policy if exists city_places_edit_admin on public.city_places;
create policy city_places_edit_admin on public.city_places for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists city_places_delete_admin on public.city_places;
create policy city_places_delete_admin on public.city_places for delete to authenticated
  using ((select public.is_admin()));

-- Only an authorized SERVER importer writes official transport data.
-- Community transport places remain in city_places, with community attribution.
create table if not exists public.burgasbus_stops (
  id text primary key check (char_length(id) between 1 and 200),
  name text not null check (char_length(name) between 1 and 500),
  stop_code text,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180)
);
create table if not exists public.burgasbus_live (
  id integer primary key check (id = 1),
  payload jsonb not null check (
    jsonb_typeof(payload) = 'object' and payload ?& array['vehicles','fetched_at']
    and jsonb_typeof(payload->'vehicles') = 'array'
    and jsonb_typeof(payload->'fetched_at') = 'number'
    and octet_length(payload::text) < 2000000
  )
);
alter table public.burgasbus_stops enable row level security;
alter table public.burgasbus_live enable row level security;
revoke all on public.burgasbus_stops, public.burgasbus_live from public, anon, authenticated;
grant select on public.burgasbus_stops, public.burgasbus_live to anon, authenticated;
grant all on public.burgasbus_stops, public.burgasbus_live to service_role;
drop policy if exists burgasbus_stops_read on public.burgasbus_stops;
create policy burgasbus_stops_read on public.burgasbus_stops for select to anon, authenticated using (true);
drop policy if exists burgasbus_live_read on public.burgasbus_live;
create policy burgasbus_live_read on public.burgasbus_live for select to anon, authenticated using (true);

-- Atomic replacement: a failed import cannot leave a half-deleted stop catalogue.
create or replace function public.replace_burgasbus_stops(p_stops jsonb)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if jsonb_typeof(p_stops) <> 'array' or jsonb_array_length(p_stops) = 0
     or jsonb_array_length(p_stops) > 20000 then
    raise exception 'Expected a non-empty official stops array, up to 20000 stops';
  end if;
  perform pg_advisory_xact_lock(2027, 1004);
  insert into public.burgasbus_stops(id,name,stop_code,latitude,longitude)
    select id,name,stop_code,latitude,longitude
    from jsonb_to_recordset(p_stops) as s(id text,name text,stop_code text,latitude double precision,longitude double precision)
  on conflict (id) do update set name=excluded.name, stop_code=excluded.stop_code,
    latitude=excluded.latitude, longitude=excluded.longitude;
  delete from public.burgasbus_stops where id not in (select value->>'id' from jsonb_array_elements(p_stops));
end;
$$;
revoke all on function public.replace_burgasbus_stops(jsonb) from public, anon, authenticated;
grant execute on function public.replace_burgasbus_stops(jsonb) to service_role;

notify pgrst, 'reload schema';
commit;
