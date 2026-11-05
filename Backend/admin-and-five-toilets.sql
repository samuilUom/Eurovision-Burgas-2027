-- Run the WHOLE file as the project owner in Supabase SQL Editor.
-- Promotes only the requested email and adds five actual OSM-mapped toilets.
-- Does not overwrite existing toilet records, remove demo data or change access policies.
-- Source attribution and uncertainty are retained in each app-visible accessNote.
begin;
-- Identifies the recreated account by email, not its deleted user ID.
-- Does not change passwords, email confirmation, or other accounts.
do $$
declare account_id uuid; account_name text;
begin
  select id, left(trim(coalesce(raw_user_meta_data->>'display_name', 'Samuil')), 50)
    into strict account_id, account_name
    from auth.users where lower(email) = 'samuil.ivanov2008@gmail.com';
  if char_length(account_name) < 2 then account_name := 'Samuil'; end if;
  insert into public.profiles(id, display_name, role)
    values (account_id, account_name, 'admin')
    on conflict(id) do update set role = 'admin';
end;
$$;

insert into public.toilets(id, created_by, payload)
select p->>'id', u.id, p
from jsonb_array_elements('[{"id": "osm-node-3287240667", "name": "Обществена тоалетна — център", "address": "Централна градска част, Бургас", "latitude": 42.4965566, "longitude": 27.4718872, "kind": "Обществена тоалетна", "currency": "EUR", "price": null, "hours": null, "amenities": [], "accessNote": "Място, отбелязано като тоалетна в OpenStreetMap. Няма проверка на място; текущите часове, цена и удобства не са потвърдени. Името описва района, а не официално наименование. Източник: © OpenStreetMap contributors (ODbL), https://www.openstreetmap.org/node/3287240667 . Данни извлечени на 22.09.2026. https://www.openstreetmap.org/copyright", "isDemo": false, "verifiedAt": null}, {"id": "osm-way-330453563", "name": "Обществена тоалетна — Автогара Юг", "address": "Район Автогара Юг, Бургас", "latitude": 42.4908858, "longitude": 27.4745499, "kind": "Обществена тоалетна", "currency": "EUR", "price": null, "hours": null, "amenities": [], "accessNote": "Място, отбелязано като тоалетна в OpenStreetMap. Няма проверка на място; текущите часове, цена и удобства не са потвърдени. Името описва района, а не официално наименование. Източник: © OpenStreetMap contributors (ODbL), https://www.openstreetmap.org/way/330453563 . Данни извлечени на 22.09.2026. https://www.openstreetmap.org/copyright", "isDemo": false, "verifiedAt": null}, {"id": "osm-node-3287240668", "name": "Обществена тоалетна — Морска градина", "address": "Морска градина, Бургас", "latitude": 42.4994874, "longitude": 27.4806312, "kind": "Обществена тоалетна", "currency": "EUR", "price": null, "hours": null, "amenities": [], "accessNote": "Място, отбелязано като тоалетна в OpenStreetMap. Няма проверка на място; текущите часове, цена и удобства не са потвърдени. Името описва района, а не официално наименование. Източник: © OpenStreetMap contributors (ODbL), https://www.openstreetmap.org/node/3287240668 . Данни извлечени на 22.09.2026. https://www.openstreetmap.org/copyright", "isDemo": false, "verifiedAt": null}, {"id": "osm-way-985556845", "name": "Обществена тоалетна — Морска градина (юг)", "address": "Южна част на Морската градина, Бургас", "latitude": 42.4954691, "longitude": 27.4808116, "kind": "Обществена тоалетна", "currency": "EUR", "price": null, "hours": null, "amenities": [], "accessNote": "Място, отбелязано като тоалетна в OpenStreetMap. Няма проверка на място; текущите часове, цена и удобства не са потвърдени. Името описва района, а не официално наименование. Източник: © OpenStreetMap contributors (ODbL), https://www.openstreetmap.org/way/985556845 . Данни извлечени на 22.09.2026. https://www.openstreetmap.org/copyright", "isDemo": false, "verifiedAt": null}, {"id": "osm-node-5063648843", "name": "Обществена тоалетна — крайбрежна алея", "address": "Южна крайбрежна зона, Бургас", "latitude": 42.4915754, "longitude": 27.480838, "kind": "Обществена тоалетна", "currency": "EUR", "price": null, "hours": null, "amenities": [], "accessNote": "Място, отбелязано като тоалетна в OpenStreetMap. Няма проверка на място; текущите часове, цена и удобства не са потвърдени. Името описва района, а не официално наименование. В източника е отбелязано сезонно ползване: пролет, лято и есен. Източник: © OpenStreetMap contributors (ODbL), https://www.openstreetmap.org/node/5063648843 . Данни извлечени на 22.09.2026. https://www.openstreetmap.org/copyright", "isDemo": false, "verifiedAt": null}]'::jsonb) as entries(p)
cross join auth.users u
where lower(u.email) = 'samuil.ivanov2008@gmail.com'
on conflict(id) do nothing;

select p.id, p.display_name, p.role from public.profiles p join auth.users u on u.id=p.id where lower(u.email)='samuil.ivanov2008@gmail.com';
select id, payload->>'name' as name from public.toilets where id in ('osm-node-3287240667','osm-way-330453563','osm-node-3287240668','osm-way-985556845','osm-node-5063648843');
commit;
