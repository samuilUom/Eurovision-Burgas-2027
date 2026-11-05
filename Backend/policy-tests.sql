-- Run after setup.sql in an isolated Supabase test project, as SQL Editor owner.
-- Success ends in ROLLBACK. A raised exception identifies a failed boundary.
begin;
insert into auth.users(id, email, raw_user_meta_data) values
 ('f0100000-0000-0000-0000-000000000001', 'policy-a@example.invalid', '{"display_name":"User A","role":"admin"}'),
 ('f0100000-0000-0000-0000-000000000002', 'policy-b@example.invalid', '{"display_name":"User B"}'),
 ('f0100000-0000-0000-0000-000000000003', 'policy-admin@example.invalid', '{"display_name":"Admin"}');
do $$ begin
 if (select role from public.profiles where id='f0100000-0000-0000-0000-000000000001') <> 'user' then
   raise exception 'FAIL: signup metadata escalated role';
 end if;
end $$;
update public.profiles set role='admin' where id='f0100000-0000-0000-0000-000000000003';

set local role authenticated;
select set_config('request.jwt.claim.sub','f0100000-0000-0000-0000-000000000001',true);
insert into public.toilets(id,created_by,payload) values ('policy-place','f0100000-0000-0000-0000-000000000001',
 '{"id":"policy-place","name":"Test toilet","address":"Burgas centre","latitude":42.497,"longitude":27.473,"kind":"Public","currency":"EUR","price":0,"amenities":[],"accessNote":"Test","isDemo":false}');
insert into public.reviews(id,toilet_id,author_id,payload) values
 ('f0200000-0000-0000-0000-000000000001','policy-place','f0100000-0000-0000-0000-000000000001',
 '{"id":"f0200000-0000-0000-0000-000000000001","toiletID":"policy-place","authorID":"f0100000-0000-0000-0000-000000000001","scores":{"soap":4},"comment":"Test","photos":[],"updatedAt":0}');
insert into public.favorites values ('f0100000-0000-0000-0000-000000000001','policy-place');
insert into public.reports values ('f0300000-0000-0000-0000-000000000001','policy-place','f0100000-0000-0000-0000-000000000001',
 '{"id":"f0300000-0000-0000-0000-000000000001","toiletID":"policy-place","category":"hours","message":"Hours need updating","createdAt":0}');
do $$ declare n integer; begin
 update public.toilets set payload=jsonb_set(payload,'{name}','"Unpermitted edit"') where id='policy-place';
 get diagnostics n = row_count;
 if n <> 0 then raise exception 'FAIL: user edited a toilet'; end if;
 delete from public.toilets where id='policy-place';
 get diagnostics n = row_count;
 if n <> 0 then raise exception 'FAIL: user deleted a toilet'; end if;
 begin
   update public.profiles set role='admin' where id='f0100000-0000-0000-0000-000000000001';
   raise exception 'FAIL: user changed own role';
 exception when insufficient_privilege then null; end;
 begin
   update public.reviews set payload=jsonb_set(payload,'{scores,soap}','9') where id='f0200000-0000-0000-0000-000000000001';
   raise exception 'FAIL: invalid score accepted';
 exception when check_violation then null; end;
 begin
   insert into public.toilets(id,created_by,payload)
   select 'false-verified','f0100000-0000-0000-0000-000000000001', jsonb_set(jsonb_set(payload,'{id}','"false-verified"'),'{verifiedAt}','0') from public.toilets where id='policy-place';
   raise exception 'FAIL: user marked new toilet verified';
 exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub','f0100000-0000-0000-0000-000000000002',true);
do $$ declare n integer; begin
 if exists(select 1 from public.favorites where toilet_id='policy-place') then raise exception 'FAIL: another user sees favorites'; end if;
 if exists(select 1 from public.reports where toilet_id='policy-place') then raise exception 'FAIL: another user sees reports'; end if;
 update public.reviews set payload=jsonb_set(payload,'{comment}','"Hijacked"') where id='f0200000-0000-0000-0000-000000000001';
 get diagnostics n = row_count;
 if n <> 0 then raise exception 'FAIL: another user edited review'; end if;
 begin
   insert into public.favorites values ('f0100000-0000-0000-0000-000000000001','policy-place');
   raise exception 'FAIL: spoofed favorite owner accepted';
 exception when insufficient_privilege then null; end;
end $$;
insert into public.reviews(id,toilet_id,author_id,payload) values
 ('f0200000-0000-0000-0000-000000000002','policy-place','f0100000-0000-0000-0000-000000000002',
 '{"id":"f0200000-0000-0000-0000-000000000002","toiletID":"policy-place","authorID":"f0100000-0000-0000-0000-000000000002","scores":{"soap":2},"comment":"Second user","photos":[],"updatedAt":0}');

select set_config('request.jwt.claim.sub','f0100000-0000-0000-0000-000000000003',true);
do $$ declare n integer; begin
 if not exists(select 1 from public.reports where toilet_id='policy-place') then raise exception 'FAIL: admin cannot see report'; end if;
 update public.toilets set payload=jsonb_set(payload,'{name}','"Admin edited"') where id='policy-place';
 get diagnostics n = row_count;
 if n <> 1 then raise exception 'FAIL: admin cannot edit toilet'; end if;
 if (select count(*) from public.reviews where toilet_id='policy-place') <> 2 then raise exception 'FAIL: multi-user reviews missing'; end if;
 delete from public.toilets where id='policy-place';
 get diagnostics n = row_count;
 if n <> 1 then raise exception 'FAIL: admin cannot delete toilet'; end if;
 if exists(select 1 from public.reviews where toilet_id='policy-place') then raise exception 'FAIL: reviews not cascaded'; end if;
end $$;
reset role;
do $$ begin
 if exists(select 1 from public.favorites where toilet_id='policy-place') or exists(select 1 from public.reports where toilet_id='policy-place') then
   raise exception 'FAIL: private dependent records not cascaded';
 end if;
end $$;
set local role anon;
do $$ begin
 begin
   insert into public.favorites values ('f0100000-0000-0000-0000-000000000001','policy-place');
   raise exception 'FAIL: anonymous write accepted';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
