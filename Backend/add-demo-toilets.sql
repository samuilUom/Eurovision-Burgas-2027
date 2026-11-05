-- Run this complete file in the existing project's Supabase SQL Editor.
-- Adds six fictional, clearly labelled demo toilets for shared-device testing.
-- Does not change accounts, passwords, roles, grants or row-level policies.
-- Re-running preserves existing records (including edits/reviews).
begin;
create or replace function public.valid_toilet(p jsonb, row_id text) returns boolean
language plpgsql immutable set search_path = '' as $$
declare h jsonb; a jsonb;
begin
  if jsonb_typeof(p) <> 'object' or octet_length(p::text) > 16384 or not (p ?& array['id','name','address','latitude','longitude','kind','currency','amenities','accessNote','isDemo']) then return false; end if;
  if jsonb_typeof(p->'id') <> 'string' or p->>'id' <> row_id or char_length(row_id) > 100 then return false; end if;
  if jsonb_typeof(p->'name') <> 'string' or char_length(trim(p->>'name')) not between 2 and 100
     or jsonb_typeof(p->'address') <> 'string' or char_length(trim(p->>'address')) not between 3 and 250
     or jsonb_typeof(p->'kind') <> 'string' or char_length(p->>'kind') not between 1 and 60
     or jsonb_typeof(p->'accessNote') <> 'string' or char_length(p->>'accessNote') > 2000 then return false; end if;
  if jsonb_typeof(p->'latitude') <> 'number' or jsonb_typeof(p->'longitude') <> 'number'
     or (p->>'latitude')::numeric not between 42.30 and 42.75 or (p->>'longitude')::numeric not between 27.20 and 27.65 then return false; end if;
  if jsonb_typeof(p->'isDemo') <> 'boolean' or jsonb_typeof(p->'currency') <> 'string' or p->>'currency' !~ '^[A-Z]{3}$' then return false; end if;
  if p ? 'price' and p->'price' <> 'null'::jsonb then
    if jsonb_typeof(p->'price') <> 'number' or (p->>'price')::numeric not between 0 and 1000 then return false; end if;
  end if;
  if p ? 'verifiedAt' and p->'verifiedAt' <> 'null'::jsonb and jsonb_typeof(p->'verifiedAt') <> 'number' then return false; end if;
  if jsonb_typeof(p->'amenities') <> 'array' or jsonb_array_length(p->'amenities') > 3 then return false; end if;
  for a in select value from jsonb_array_elements(p->'amenities') loop
    if jsonb_typeof(a) <> 'string' or a #>> '{}' not in ('wheelchair','changingTable','water') then return false; end if;
  end loop;
  if p ? 'hours' and p->'hours' <> 'null'::jsonb then
    if jsonb_typeof(p->'hours') <> 'array' or jsonb_array_length(p->'hours') > 28 then return false; end if;
    for h in select value from jsonb_array_elements(p->'hours') loop
      if not (h ?& array['weekday','opens','closes']) then return false; end if;
      if jsonb_typeof(h->'weekday') <> 'number' or jsonb_typeof(h->'opens') <> 'number' or jsonb_typeof(h->'closes') <> 'number' then return false; end if;
      if (h->>'weekday') !~ '^[0-9]+$' or (h->>'opens') !~ '^[0-9]+$' or (h->>'closes') !~ '^[0-9]+$' then return false; end if;
      if (h->>'weekday')::int not between 1 and 7 or (h->>'opens')::int not between 0 and 1439
         or (h->>'closes')::int not between 0 and 1440 or (h->>'opens')::int = (h->>'closes')::int then return false; end if;
    end loop;
  end if;
  return true;
exception when others then return false;
end;
$$;

do $$
begin
  if not exists (select 1 from public.profiles where id = '6200c167-1adf-47ec-bb7b-23a38d038f1d'::uuid) then
    raise exception 'Expected owner profile is missing. No changes made.';
  end if;
end;
$$;
insert into public.toilets (id, created_by, payload)
select p->>'id', '6200c167-1adf-47ec-bb7b-23a38d038f1d'::uuid, p
from jsonb_array_elements('[{"id": "shared-demo-garden", "name": "ДЕМО • Морска градина", "address": "Примерна точка • район Морска градина", "latitude": 42.5006, "longitude": 27.4822, "kind": "Демо обект", "price": 0, "currency": "EUR", "amenities": ["wheelchair", "water"], "hours": [{"weekday": 1, "opens": 480, "closes": 1320}, {"weekday": 2, "opens": 480, "closes": 1320}, {"weekday": 3, "opens": 480, "closes": 1320}, {"weekday": 4, "opens": 480, "closes": 1320}, {"weekday": 5, "opens": 480, "closes": 1320}, {"weekday": 6, "opens": 480, "closes": 1320}, {"weekday": 7, "opens": 480, "closes": 1320}], "accessNote": "Изцяло примерни данни за тестване. Наличието на тоалетна, цената, графикът и удобствата НЕ са проверени.", "isDemo": true, "verifiedAt": null}, {"id": "shared-demo-pier", "name": "ДЕМО • До Моста", "address": "Примерна точка • район До Моста", "latitude": 42.4967, "longitude": 27.485, "kind": "Демо обект", "price": 0.5, "currency": "EUR", "amenities": ["water"], "hours": [{"weekday": 1, "opens": 540, "closes": 1200}, {"weekday": 2, "opens": 540, "closes": 1200}, {"weekday": 3, "opens": 540, "closes": 1200}, {"weekday": 4, "opens": 540, "closes": 1200}, {"weekday": 5, "opens": 540, "closes": 1200}, {"weekday": 6, "opens": 540, "closes": 1200}, {"weekday": 7, "opens": 540, "closes": 1200}], "accessNote": "Изцяло примерни данни за тестване. Наличието на тоалетна, цената, графикът и удобствата НЕ са проверени.", "isDemo": true, "verifiedAt": null}, {"id": "shared-demo-center", "name": "ДЕМО • Площад Тройката", "address": "Примерна точка • район Площад Тройката", "latitude": 42.4979, "longitude": 27.4706, "kind": "Демо обект", "price": 0, "currency": "EUR", "amenities": ["wheelchair", "changingTable", "water"], "hours": [{"weekday": 1, "opens": 0, "closes": 1440}, {"weekday": 2, "opens": 0, "closes": 1440}, {"weekday": 3, "opens": 0, "closes": 1440}, {"weekday": 4, "opens": 0, "closes": 1440}, {"weekday": 5, "opens": 0, "closes": 1440}, {"weekday": 6, "opens": 0, "closes": 1440}, {"weekday": 7, "opens": 0, "closes": 1440}], "accessNote": "Изцяло примерни данни за тестване. Наличието на тоалетна, цената, графикът и удобствата НЕ са проверени.", "isDemo": true, "verifiedAt": null}, {"id": "shared-demo-station", "name": "ДЕМО • До гарата", "address": "Примерна точка • район До гарата", "latitude": 42.4904, "longitude": 27.4713, "kind": "Демо обект", "price": 0.5, "currency": "EUR", "amenities": ["water"], "hours": [{"weekday": 1, "opens": 360, "closes": 1380}, {"weekday": 2, "opens": 360, "closes": 1380}, {"weekday": 3, "opens": 360, "closes": 1380}, {"weekday": 4, "opens": 360, "closes": 1380}, {"weekday": 5, "opens": 360, "closes": 1380}, {"weekday": 6, "opens": 360, "closes": 1380}, {"weekday": 7, "opens": 360, "closes": 1380}], "accessNote": "Изцяло примерни данни за тестване. Наличието на тоалетна, цената, графикът и удобствата НЕ са проверени.", "isDemo": true, "verifiedAt": null}, {"id": "shared-demo-lazur", "name": "ДЕМО • Лазур", "address": "Примерна точка • район Лазур", "latitude": 42.5128, "longitude": 27.4756, "kind": "Демо обект", "price": null, "currency": "EUR", "amenities": ["changingTable", "water"], "hours": null, "accessNote": "Изцяло примерни данни за тестване. Наличието на тоалетна, цената, графикът и удобствата НЕ са проверени.", "isDemo": true, "verifiedAt": null}, {"id": "shared-demo-park", "name": "ДЕМО • Парк Изгрев", "address": "Примерна точка • район Парк Изгрев", "latitude": 42.5241, "longitude": 27.4617, "kind": "Демо обект", "price": 0, "currency": "EUR", "amenities": ["wheelchair", "water"], "hours": [{"weekday": 1, "opens": 420, "closes": 1260}, {"weekday": 2, "opens": 420, "closes": 1260}, {"weekday": 3, "opens": 420, "closes": 1260}, {"weekday": 4, "opens": 420, "closes": 1260}, {"weekday": 5, "opens": 420, "closes": 1260}, {"weekday": 6, "opens": 420, "closes": 1260}, {"weekday": 7, "opens": 420, "closes": 1260}], "accessNote": "Изцяло примерни данни за тестване. Наличието на тоалетна, цената, графикът и удобствата НЕ са проверени.", "isDemo": true, "verifiedAt": null}]'::jsonb) as entries(p)
on conflict (id) do nothing;
commit;
select id, payload->>'name' as name from public.toilets where id like 'shared-demo-%' order by id;
