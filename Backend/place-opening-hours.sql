-- Add shared opening hours after category-places-and-transit.sql.
-- Preserves places, accounts, reviews, favorites and existing row-level permissions.
begin;

create or replace function public.valid_city_hours(value jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare h jsonb;
begin
  if value is null or value = 'null'::jsonb then return true; end if;
  if jsonb_typeof(value) <> 'array' then return false; end if;
  if jsonb_array_length(value) > 28 then return false; end if;
  for h in select * from jsonb_array_elements(value) loop
    if jsonb_typeof(h) <> 'object' or not (h ?& array['weekday','opens','closes']) then return false; end if;
    if jsonb_typeof(h->'weekday') <> 'number' or jsonb_typeof(h->'opens') <> 'number'
       or jsonb_typeof(h->'closes') <> 'number' then return false; end if;
    if h->>'weekday' !~ '^[0-9]+$' or h->>'opens' !~ '^[0-9]+$' or h->>'closes' !~ '^[0-9]+$' then return false; end if;
    if (h->>'weekday')::int not between 1 and 7 or (h->>'opens')::int not between 0 and 1439
       or (h->>'closes')::int not between 0 and 1440 or (h->>'opens')::int = (h->>'closes')::int then return false; end if;
  end loop;
  return true;
exception when others then return false;
end;
$$;
revoke all on function public.valid_city_hours(jsonb) from public;
grant execute on function public.valid_city_hours(jsonb) to anon, authenticated, service_role;
alter table public.city_places add column if not exists hours jsonb;
do $$ begin
  if not exists(select 1 from pg_constraint where conname = 'city_places_hours_valid'
      and conrelid = 'public.city_places'::regclass) then
    alter table public.city_places add constraint city_places_hours_valid check (public.valid_city_hours(hours) is true);
  end if;
end $$;
grant insert(hours), update(hours) on public.city_places to authenticated;
notify pgrst, 'reload schema';
commit;
