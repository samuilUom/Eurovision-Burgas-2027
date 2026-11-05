-- Eurovision Burgas 2027 / 0.11.0: shared restaurant reviews and photos.
-- Run the WHOLE file in the existing project's SQL Editor.
-- Requires category-places-and-transit.sql. Preserves all existing place/toilet data.
-- Re-running only replaces this feature's functions, triggers and policies.
begin;

create or replace function public.restaurant_jpeg_valid(encoded text, max_bytes integer)
returns boolean language plpgsql immutable set search_path = '' as $$
declare bytes bytea;
begin
  if encoded is null or char_length(encoded) > ((max_bytes + 2) / 3) * 4 then return false; end if;
  bytes := decode(encoded, 'base64');
  return octet_length(bytes) between 4 and max_bytes and substring(bytes from 1 for 3) = '\xffd8ff'::bytea;
exception when others then return false;
end;
$$;
revoke all on function public.restaurant_jpeg_valid(text,integer) from public;
grant execute on function public.restaurant_jpeg_valid(text,integer) to authenticated;

create table if not exists public.restaurant_reviews (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.city_places(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '' check (char_length(comment) <= 2000),
  updated_at timestamptz not null default now(),
  unique(place_id, author_id)
);
create index if not exists restaurant_reviews_page_idx on public.restaurant_reviews(place_id,updated_at desc,id desc);
create index if not exists restaurant_reviews_author_idx on public.restaurant_reviews(author_id);

create table if not exists public.restaurant_photos (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.city_places(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null default '' check (char_length(caption) <= 300),
  thumbnail_base64 text not null check (public.restaurant_jpeg_valid(thumbnail_base64,65000)),
  image_base64 text not null check (public.restaurant_jpeg_valid(image_base64,500000)),
  created_at timestamptz not null default now()
);
create index if not exists restaurant_photos_page_idx on public.restaurant_photos(place_id,created_at desc,id desc);
create index if not exists restaurant_photos_author_idx on public.restaurant_photos(author_id,place_id);

alter table public.restaurant_reviews enable row level security;
alter table public.restaurant_photos enable row level security;
revoke all on public.restaurant_reviews, public.restaurant_photos from public, anon, authenticated;
grant select on public.restaurant_reviews, public.restaurant_photos to anon, authenticated;
grant insert (place_id,author_id,rating,comment), update (rating,comment), delete on public.restaurant_reviews to authenticated;
grant insert (id,place_id,author_id,caption,thumbnail_base64,image_base64), delete on public.restaurant_photos to authenticated;

drop policy if exists restaurant_reviews_read on public.restaurant_reviews;
create policy restaurant_reviews_read on public.restaurant_reviews for select to anon,authenticated using (true);
drop policy if exists restaurant_reviews_add on public.restaurant_reviews;
create policy restaurant_reviews_add on public.restaurant_reviews for insert to authenticated with check (author_id = (select auth.uid()));
drop policy if exists restaurant_reviews_edit on public.restaurant_reviews;
create policy restaurant_reviews_edit on public.restaurant_reviews for update to authenticated
  using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));
drop policy if exists restaurant_reviews_remove on public.restaurant_reviews;
create policy restaurant_reviews_remove on public.restaurant_reviews for delete to authenticated
  using (author_id = (select auth.uid()) or (select public.is_admin()));
drop policy if exists restaurant_photos_read on public.restaurant_photos;
create policy restaurant_photos_read on public.restaurant_photos for select to anon,authenticated using (true);
drop policy if exists restaurant_photos_add on public.restaurant_photos;
create policy restaurant_photos_add on public.restaurant_photos for insert to authenticated with check (author_id = (select auth.uid()));
drop policy if exists restaurant_photos_remove on public.restaurant_photos;
create policy restaurant_photos_remove on public.restaurant_photos for delete to authenticated
  using (author_id = (select auth.uid()) or (select public.is_admin()));

create or replace function public.restaurant_contribution_guard()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if not exists (select 1 from public.city_places p where p.id = new.place_id and p.category = 'restaurants') then
    raise exception 'Restaurant not found';
  end if;
  if tg_table_name = 'restaurant_reviews' then
    new.updated_at := now();
  else
    -- Serializes simultaneous uploads by this author to this restaurant.
    perform pg_advisory_xact_lock(hashtextextended(new.author_id::text || new.place_id::text, 2027));
    if not exists (select 1 from public.restaurant_photos p where p.id = new.id)
       and (select count(*) from public.restaurant_photos p where p.place_id = new.place_id and p.author_id = new.author_id) >= 10 then
      raise exception 'Maximum 10 photos per person per restaurant';
    end if;
    new.created_at := now();
  end if;
  return new;
end;
$$;
revoke all on function public.restaurant_contribution_guard() from public,anon,authenticated;
drop trigger if exists restaurant_review_guard on public.restaurant_reviews;
create trigger restaurant_review_guard before insert or update on public.restaurant_reviews
  for each row execute function public.restaurant_contribution_guard();
drop trigger if exists restaurant_photo_guard on public.restaurant_photos;
create trigger restaurant_photo_guard before insert on public.restaurant_photos
  for each row execute function public.restaurant_contribution_guard();

-- Invoker functions retain the caller's RLS and column grants, never admin rights.
create or replace function public.save_restaurant_review(p_place_id uuid,p_rating integer,p_comment text)
returns setof public.restaurant_reviews language sql security invoker set search_path = '' as $$
  insert into public.restaurant_reviews(place_id,author_id,rating,comment)
  values(p_place_id,auth.uid(),p_rating,btrim(p_comment))
  on conflict(place_id,author_id) do update set rating=excluded.rating,comment=excluded.comment
  returning *;
$$;
revoke all on function public.save_restaurant_review(uuid,integer,text) from public,anon;
grant execute on function public.save_restaurant_review(uuid,integer,text) to authenticated;

-- Stable photo IDs make retries idempotent, including at the ten-photo quota.
create or replace function public.add_restaurant_photo(p_id uuid,p_place_id uuid,p_caption text,p_image text,p_thumbnail text)
returns table(id uuid) language plpgsql security invoker set search_path = '' as $$
begin
  insert into public.restaurant_photos(id,place_id,author_id,caption,image_base64,thumbnail_base64)
  values(p_id,p_place_id,auth.uid(),btrim(p_caption),p_image,p_thumbnail)
  on conflict do nothing;
  return query select p.id from public.restaurant_photos p
    where p.id = p_id and p.place_id = p_place_id and p.author_id = auth.uid();
end;
$$;
revoke all on function public.add_restaurant_photo(uuid,uuid,text,text,text) from public,anon;
grant execute on function public.add_restaurant_photo(uuid,uuid,text,text,text) to authenticated;

-- Full counts/average cover ALL reviews. Pages contain at most 20 items and only
-- thumbnails. The full image is fetched by ID only after the user opens a photo.
create or replace function public.restaurant_community(p_place_id uuid,p_review_offset integer default 0,p_photo_offset integer default 0)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'review_count',(select count(*) from public.restaurant_reviews r where r.place_id=p_place_id),
    'photo_count',(select count(*) from public.restaurant_photos p where p.place_id=p_place_id),
    'average_rating',(select avg(r.rating) from public.restaurant_reviews r where r.place_id=p_place_id),
    'my_review',(select to_jsonb(r) || jsonb_build_object('author_name',a.display_name)
      from public.restaurant_reviews r join public.profiles a on a.id=r.author_id
      where r.place_id=p_place_id and r.author_id=auth.uid()),
    'reviews',coalesce((select jsonb_agg(to_jsonb(r) order by r.updated_at desc,r.id desc) from (
      select r.*,a.display_name as author_name from public.restaurant_reviews r join public.profiles a on a.id=r.author_id
      where r.place_id=p_place_id order by r.updated_at desc,r.id desc limit 20 offset greatest(0,p_review_offset)
    ) r),'[]'::jsonb),
    'photos',coalesce((select jsonb_agg(to_jsonb(p) order by p.created_at desc,p.id desc) from (
      select p.id,p.place_id,p.author_id,p.caption,p.thumbnail_base64,p.created_at,a.display_name as author_name
      from public.restaurant_photos p join public.profiles a on a.id=p.author_id
      where p.place_id=p_place_id order by p.created_at desc,p.id desc limit 20 offset greatest(0,p_photo_offset)
    ) p),'[]'::jsonb)
  );
$$;
revoke all on function public.restaurant_community(uuid,integer,integer) from public;
grant execute on function public.restaurant_community(uuid,integer,integer) to anon,authenticated;

-- Apple Maps-only results can become a single shared place. A lock + nearby
-- exact-name match avoids separate review pages when two phones add it together.
create or replace function public.register_restaurant(p_name text,p_address text,p_latitude double precision,p_longitude double precision,p_website text default null)
returns setof public.city_places language plpgsql security invoker set search_path = '' as $$
declare found_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if p_latitude is null or p_longitude is null or p_latitude not between 42.30 and 42.75 or p_longitude not between 27.20 and 27.65 then
    raise exception 'Choose a restaurant in Burgas';
  end if;
  perform pg_advisory_xact_lock(2027,710);
  select p.id into found_id from public.city_places p
    where p.category='restaurants'
      and lower(regexp_replace(btrim(p.name),'\s+',' ','g')) = lower(regexp_replace(btrim(p_name),'\s+',' ','g'))
      and abs(p.latitude-p_latitude)<0.0005 and abs(p.longitude-p_longitude)<0.0007
    order by abs(p.latitude-p_latitude)+abs(p.longitude-p_longitude),p.id limit 1;
  if found_id is null then
    insert into public.city_places(created_by,category,name,address,latitude,longitude,website,notes)
      values(auth.uid(),'restaurants',btrim(p_name),btrim(p_address),p_latitude,p_longitude,p_website,'') returning public.city_places.id into found_id;
  end if;
  return query select p.* from public.city_places p where p.id=found_id;
end;
$$;
revoke all on function public.register_restaurant(text,text,double precision,double precision,text) from public,anon;
grant execute on function public.register_restaurant(text,text,double precision,double precision,text) to authenticated;

notify pgrst, 'reload schema';
commit;

select 'Restaurant community ready' as result;
