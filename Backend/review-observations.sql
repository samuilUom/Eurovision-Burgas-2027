-- Optional hardening for the existing project. Old and new reviews remain supported.
-- The current schema already stores the new JSON field; this adds server-side validation.
begin;
create or replace function public.valid_review(p jsonb, row_id uuid, toilet text, author uuid) returns boolean
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

commit;
