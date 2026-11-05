-- MANUAL SETUP: fuel/EV categories, retaining healthcare and all existing records.
-- Run this entire file yourself in the existing Supabase SQL Editor.
-- Preserves records, ownership, grants and all row-level policies. Safe to rerun.
begin;
alter table public.city_places drop constraint if exists city_places_category_check;
alter table public.city_places add constraint city_places_category_check
  check (category in ('restaurants','atms','shopping','hospitals','pharmacies','fuel','charging','transport'));
alter table public.city_places drop constraint if exists nonstop_shops_only;
alter table public.city_places add constraint nonstop_shops_only
  check (category in ('shopping','pharmacies','fuel','charging') or is_nonstop is null);

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


notify pgrst, 'reload schema';
commit;

select 'Fuel and charging categories ready' as result;
