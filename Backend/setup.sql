-- Run once in the SQL Editor of a NEW Supabase project.
-- No service-role/secret key belongs in the iPhone app.
begin;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 50),
  role text not null default 'user' check (role in ('user', 'admin'))
);
alter table public.profiles enable row level security;

create function public.create_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare n text;
begin
  n := left(trim(coalesce(new.raw_user_meta_data->>'display_name', 'Потребител')), 50);
  if char_length(n) < 2 then n := 'Потребител'; end if;
  insert into public.profiles(id, display_name, role) values(new.id, n, 'user');
  return new;
end;
$$;
revoke all on function public.create_profile() from public, anon, authenticated;
create trigger create_profile_after_signup after insert on auth.users for each row execute function public.create_profile();
-- Covers accounts created before this migration. All begin as regular users.
insert into public.profiles(id, display_name)
select id, 'Потребител' from auth.users on conflict(id) do nothing;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = (select auth.uid()) and role = 'admin');
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

create function public.valid_toilet(p jsonb, row_id text) returns boolean
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

create table public.toilets (
  id text primary key,
  created_by uuid not null references public.profiles(id),
  payload jsonb not null check (public.valid_toilet(payload, id) is true),
  created_at timestamptz not null default now()
);
alter table public.toilets enable row level security;
create index toilets_created_by_idx on public.toilets(created_by);

create function public.valid_review(p jsonb, row_id uuid, toilet text, author uuid) returns boolean
language plpgsql immutable set search_path = '' as $$
declare item record; photo jsonb;
begin
  if jsonb_typeof(p) <> 'object' or not (p ?& array['id','toiletID','authorID','scores','comment','photos','updatedAt']) then return false; end if;
  if jsonb_typeof(p->'id') <> 'string' or jsonb_typeof(p->'toiletID') <> 'string' or jsonb_typeof(p->'authorID') <> 'string'
    or lower(p->>'id') <> row_id::text or p->>'toiletID' <> toilet or lower(p->>'authorID') <> author::text then return false; end if;
  if jsonb_typeof(p->'comment') <> 'string' or char_length(p->>'comment') > 1000 or jsonb_typeof(p->'updatedAt') <> 'number' then return false; end if;
  if jsonb_typeof(p->'scores') <> 'object' or p->'scores' = '{}'::jsonb then return false; end if;
  for item in select * from jsonb_each(p->'scores') loop
    if item.key not in ('cleanliness','maintenance','paper','soap','lighting','condition','accessibility')
       or jsonb_typeof(item.value) <> 'number' or item.value::text !~ '^[1-5]$' then return false; end if;
  end loop;
  if p ? 'observations' and p->'observations' <> 'null'::jsonb then
    if jsonb_typeof(p->'observations') <> 'object' then return false; end if;
    for item in select * from jsonb_each(p->'observations') loop
      if item.key not in ('soap','paper','water','wheelchair') or jsonb_typeof(item.value) <> 'boolean' then return false; end if;
    end loop;
  end if;
  if jsonb_typeof(p->'photos') <> 'array' or jsonb_array_length(p->'photos') > 3 or octet_length(p::text) > 4500000 then return false; end if;
  for photo in select value from jsonb_array_elements(p->'photos') loop
    if jsonb_typeof(photo) <> 'string' or char_length(photo #>> '{}') > 1400000 then return false; end if;
    perform decode(photo #>> '{}', 'base64');
  end loop;
  return true;
exception when others then return false;
end;
$$;

create table public.reviews (
  id uuid primary key,
  toilet_id text not null references public.toilets(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  payload jsonb not null check (public.valid_review(payload, id, toilet_id, author_id) is true),
  unique(toilet_id, author_id)
);
alter table public.reviews enable row level security;
create index reviews_author_idx on public.reviews(author_id);

create table public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  toilet_id text not null references public.toilets(id) on delete cascade,
  primary key(user_id, toilet_id)
);
alter table public.favorites enable row level security;
create index favorites_toilet_idx on public.favorites(toilet_id);

create function public.valid_report(p jsonb, row_id uuid, toilet text) returns boolean
language sql immutable set search_path = '' as $$
  select coalesce(jsonb_typeof(p) = 'object' and octet_length(p::text) <= 8192 and lower(p->>'id') = row_id::text and p->>'toiletID' = toilet
    and p->>'category' in ('location','hours','price','closed','accessibility','other')
    and jsonb_typeof(p->'message') = 'string' and char_length(trim(p->>'message')) between 10 and 1000
    and jsonb_typeof(p->'createdAt') = 'number', false);
$$;
create table public.reports (
  id uuid primary key,
  toilet_id text not null references public.toilets(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  payload jsonb not null check (public.valid_report(payload, id, toilet_id) is true)
);
alter table public.reports enable row level security;
create index reports_author_idx on public.reports(author_id);
create index reports_toilet_idx on public.reports(toilet_id);

-- Explicit grants remove Supabase's broad default table privileges.
revoke all on public.profiles, public.toilets, public.reviews, public.favorites, public.reports from anon, authenticated;
grant select on public.profiles, public.toilets, public.reviews to anon, authenticated;
grant update(display_name) on public.profiles to authenticated;
grant insert, delete on public.toilets to authenticated;
grant update(payload) on public.toilets to authenticated;
grant insert, update, delete on public.reviews to authenticated;
grant select, insert, delete on public.favorites to authenticated;
grant select, insert on public.reports to authenticated;

create policy profiles_read on public.profiles for select to anon, authenticated using (true);
create policy profiles_rename_self on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy toilets_read on public.toilets for select to anon, authenticated using (true);
create policy toilets_add on public.toilets for insert to authenticated with check (
  created_by = (select auth.uid()) and
  ((select public.is_admin()) or payload->'verifiedAt' is null or payload->'verifiedAt' = 'null'::jsonb)
);
create policy toilets_edit_admin on public.toilets for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy toilets_delete_admin on public.toilets for delete to authenticated using ((select public.is_admin()));
create policy reviews_read on public.reviews for select to anon, authenticated using (true);
create policy reviews_add_self on public.reviews for insert to authenticated with check (author_id = (select auth.uid()));
create policy reviews_edit_self on public.reviews for update to authenticated using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));
create policy reviews_delete_self on public.reviews for delete to authenticated using (author_id = (select auth.uid()));
create policy favorites_read_self on public.favorites for select to authenticated using (user_id = (select auth.uid()));
create policy favorites_add_self on public.favorites for insert to authenticated with check (user_id = (select auth.uid()));
create policy favorites_delete_self on public.favorites for delete to authenticated using (user_id = (select auth.uid()));
create policy reports_read_self_or_admin on public.reports for select to authenticated using (author_id = (select auth.uid()) or (select public.is_admin()));
create policy reports_add_self on public.reports for insert to authenticated with check (author_id = (select auth.uid()));
commit;

-- Profile photos (bounded image data, same owner-only update policy).
-- Run once in the existing Supabase project's SQL Editor, as project owner.
-- Existing self-only UPDATE policy applies. This grants no role-editing rights.
begin;
alter table public.profiles add column if not exists avatar_base64 text;
create or replace function public.valid_profile_avatar(value text) returns boolean
language plpgsql immutable set search_path = '' as $$
begin
  if value is null then return true; end if;
  if length(value) > 120000 or length(value) = 0 then return false; end if;
  return octet_length(decode(value, 'base64')) between 1 and 90000;
exception when others then return false;
end;
$$;
alter table public.profiles drop constraint if exists profiles_avatar_valid;
alter table public.profiles add constraint profiles_avatar_valid
  check (public.valid_profile_avatar(avatar_base64));
grant update(avatar_base64) on public.profiles to authenticated;
commit;
