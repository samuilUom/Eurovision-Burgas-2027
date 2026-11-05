"""Rebuild the reviewed, additive SQL import from the checked-in restaurant catalogue."""
from pathlib import Path
import json
root = Path(__file__).resolve().parent
rows = json.loads((root / 'burgas-restaurants.json').read_text())
assert rows and len({r['id'] for r in rows}) == len(rows)
assert '$restaurant_data$' not in json.dumps(rows, ensure_ascii=False)
# The same optional-hours migration is included so this is a single setup step.
hours = (root / 'place-opening-hours.sql').read_text()
hours = '\n'.join(line for line in hours.splitlines() if line.strip() not in ('begin;', 'commit;', "notify pgrst, 'reload schema';"))
header = f'''-- Adds {len(rows)} real restaurant listings to the EXISTING Eurovision Burgas app database.
-- Read RESTAURANTS.md for sources, corrections and limitations.
-- Run this WHOLE file in a NEW Supabase SQL query as the project owner.
-- Existing places, toilets, reviews, favorites and accounts are never overwritten or deleted.
-- Does not grant admin status or change passwords. Repeat runs skip existing records.
begin;

-- Fail before any writes if the intended administrator account is missing.
create temporary table restaurant_import_owner on commit drop as
select p.id from public.profiles p join auth.users u on u.id = p.id
where lower(u.email) = 'samuil.ivanov2008@gmail.com' and p.role = 'admin';
do $owner_check$
begin
  if (select count(*) from restaurant_import_owner) <> 1 then
    raise exception 'The existing administrator profile samuil.ivanov2008@gmail.com was not found. No restaurants were imported.';
  end if;
  if to_regclass('public.city_places') is null then
    raise exception 'Run category-places-and-transit.sql first. No restaurants were imported.';
  end if;
end;
$owner_check$;

'''
body = '''

create temporary table restaurant_import_seed on commit drop as
select * from jsonb_to_recordset($restaurant_data$
'''+json.dumps(rows,ensure_ascii=False,indent=2)+'''
$restaurant_data$::jsonb) as r(
  id uuid, category text, name text, address text, latitude double precision,
  longitude double precision, website text, notes text, is_nonstop boolean, hours jsonb
);

-- Hold concurrent inserts until this short import completes, including the duplicate check.
lock table public.city_places in share row exclusive mode;
insert into public.city_places
  (id, created_by, category, name, address, latitude, longitude, website, notes, is_nonstop, hours)
select s.id, o.id, s.category, s.name, s.address, s.latitude, s.longitude,
       s.website, s.notes, s.is_nonstop, nullif(s.hours, 'null'::jsonb)
from restaurant_import_seed s cross join restaurant_import_owner o
where not exists (
  select 1 from public.city_places p
  where p.id = s.id or (
    p.category = 'restaurants'
    and regexp_replace(lower(p.name), '[[:space:][:punct:]]+', '', 'g')
        = regexp_replace(lower(s.name), '[[:space:][:punct:]]+', '', 'g')
    and abs(p.latitude - s.latitude) < 0.0004
    and abs(p.longitude - s.longitude) < 0.0005
  )
)
on conflict (id) do nothing;

notify pgrst, 'reload schema';
commit;

-- This count includes any restaurant records you already had.
select count(*) as restaurants_in_app from public.city_places where category = 'restaurants';
'''
(root/'add-burgas-restaurants.sql').write_text(header+hours+body)
print(f'Built SQL import for {len(rows)} restaurants.')
