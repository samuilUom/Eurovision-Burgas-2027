-- Run once in the existing project's Supabase SQL Editor. Safe to run again.
-- Adds private favorites for the five MapKit categories; preserves toilet favorites.
begin;

create or replace function public.valid_city_favorite(p jsonb, row_id text, row_category text)
returns boolean language plpgsql immutable set search_path = '' as $$
begin
  if jsonb_typeof(p) <> 'object' or octet_length(p::text) > 8192
     or not (p ?& array['id','category','name','address','latitude','longitude','savedAt']) then return false; end if;
  if jsonb_typeof(p->'id') <> 'string' or p->>'id' <> row_id or row_id !~ '^[0-9a-f]{64}$'
     or jsonb_typeof(p->'category') <> 'string' or p->>'category' <> row_category
     or row_category not in ('restaurants','atms','convenience','shopping','hospitals','pharmacies','fuel','charging','transport') then return false; end if;
  if jsonb_typeof(p->'name') <> 'string' or char_length(trim(p->>'name')) not between 1 and 200
     or jsonb_typeof(p->'address') <> 'string' or char_length(p->>'address') > 500 then return false; end if;
  if jsonb_typeof(p->'latitude') <> 'number' or jsonb_typeof(p->'longitude') <> 'number'
     or (p->>'latitude')::numeric not between -90 and 90 or (p->>'longitude')::numeric not between -180 and 180
     or jsonb_typeof(p->'savedAt') <> 'number' or (p->>'savedAt')::numeric not between -100000000000 and 100000000000 then return false; end if;
  if p ? 'website' and p->'website' <> 'null'::jsonb then
    if jsonb_typeof(p->'website') <> 'string' or char_length(p->>'website') > 2048
       or p->>'website' !~* '^https?://[^[:space:]]+$' then return false; end if;
  end if;
  return true;
exception when others then return false;
end;
$$;
revoke all on function public.valid_city_favorite(jsonb,text,text) from public, anon;
grant execute on function public.valid_city_favorite(jsonb,text,text) to authenticated;

create table if not exists public.city_place_favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  place_id text not null,
  category text not null,
  payload jsonb not null,
  primary key (user_id, place_id),
  constraint city_favorite_valid check (public.valid_city_favorite(payload, place_id, category))
);
alter table public.city_place_favorites enable row level security;
revoke all on public.city_place_favorites from public, anon, authenticated;
grant select, insert, update, delete on public.city_place_favorites to authenticated;

drop policy if exists city_favorites_read_self on public.city_place_favorites;
create policy city_favorites_read_self on public.city_place_favorites for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists city_favorites_add_self on public.city_place_favorites;
create policy city_favorites_add_self on public.city_place_favorites for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists city_favorites_update_self on public.city_place_favorites;
create policy city_favorites_update_self on public.city_place_favorites for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists city_favorites_delete_self on public.city_place_favorites;
create policy city_favorites_delete_self on public.city_place_favorites for delete to authenticated
  using (user_id = (select auth.uid()));

notify pgrst, 'reload schema';
commit;
