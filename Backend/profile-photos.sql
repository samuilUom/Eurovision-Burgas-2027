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
