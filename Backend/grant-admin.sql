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
select p.id,p.display_name,p.role from public.profiles p join auth.users u on u.id=p.id where lower(u.email)='samuil.ivanov2008@gmail.com';
commit;
