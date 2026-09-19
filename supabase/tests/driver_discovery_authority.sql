-- Disposable full-schema database only. Real Auth/session rows and SQL roles,
-- with synthetic claims; this does not prove JWT verification or OTP delivery.
begin;
create temp table qa_discovery_actors (
  name text primary key, user_id uuid default gen_random_uuid(),
  session_id uuid default gen_random_uuid()
);
insert into qa_discovery_actors(name)
values ('viewer'), ('driver'), ('offline'), ('admin'), ('anonymous'), ('unverified');
create temp table qa_discovery_results(name text);
create temp table qa_discovery_baseline as
select count(*) as online_cabs from public.driver_locations
where is_online and vehicle_type_id = 'cab';
grant select on qa_discovery_actors, qa_discovery_baseline to authenticated, anon, service_role;
grant select, insert on qa_discovery_results to authenticated, anon, service_role;

create function pg_temp.qa_check(label text, value boolean) returns void
language plpgsql as $$
begin
  if value is distinct from true then raise exception 'ASSERTION FAILED: %', label; end if;
  insert into pg_temp.qa_discovery_results values(label);
end;
$$;
create function pg_temp.qa_identity(actor text) returns void
language plpgsql as $$
declare claims jsonb;
begin
  select jsonb_build_object('sub',user_id,'session_id',session_id,
    'role','authenticated','is_anonymous',name='anonymous',
    'app_metadata',jsonb_build_object('provider',case when name='admin'
      then 'admin_whatsapp_otp' else 'whatsapp_cloud_otp' end))
  into strict claims from pg_temp.qa_discovery_actors where name=actor;
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims',claims::text,true);
end;
$$;
create function pg_temp.qa_discovery_denied(label text) returns void
language plpgsql as $$
begin
  perform pg_temp.qa_check(label || ': location rows hidden', not exists (
    select 1 from public.driver_locations
    where driver_id in (select user_id from pg_temp.qa_discovery_actors)
  ));
  begin
    perform 1 from public.rpc_search_nearby_drivers(0,0,null,'cab',20);
    raise exception 'ASSERTION FAILED: search accepted %',label;
  exception when sqlstate 'PT401' then
    perform pg_temp.qa_check(label || ': search rejected',true);
  end;
  begin
    perform public.rpc_get_discover_summary(null,null,'cab');
    raise exception 'ASSERTION FAILED: summary accepted %',label;
  exception when sqlstate 'PT401' then
    perform pg_temp.qa_check(label || ': summary rejected',true);
  end;
end;
$$;

insert into auth.users(id,phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,is_anonymous)
select user_id,
  case name when 'viewer' then '+250700006101' when 'driver' then '+250700006102'
    when 'offline' then '+250700006103' when 'admin' then '+250700006104' end,
  case when name not in ('anonymous','unverified') then now() end,
  jsonb_build_object('provider',case when name='admin' then 'admin_whatsapp_otp'
    when name in ('anonymous','unverified') then 'email' else 'whatsapp_cloud_otp' end),
  '{}',name='anonymous'
from qa_discovery_actors;
insert into auth.sessions(id,user_id,created_at,not_after)
select session_id,user_id,now(),now()+interval '1 hour' from qa_discovery_actors;
update public.profiles set role='driver',is_driver=true
where id in (select user_id from qa_discovery_actors where name in ('driver','offline'));
update public.profiles set role='admin'
where id=(select user_id from qa_discovery_actors where name='admin');
insert into public.admin_whatsapp_numbers(phone_e164,country_code,display_name,is_active)
values ('+250700006104','+250','Synthetic discovery administrator',true);
insert into public.driver_locations(driver_id,latitude,longitude,vehicle_type_id,is_online)
select user_id,0.001,0.001,'cab',name='driver'
from qa_discovery_actors where name in ('driver','offline');

select pg_temp.qa_check('public key cannot execute discovery search',
  not has_function_privilege('anon','public.rpc_search_nearby_drivers(double precision,double precision,text,text,integer)','EXECUTE'));
select pg_temp.qa_check('public key cannot execute discovery summary',
  not has_function_privilege('anon','public.rpc_get_discover_summary(double precision,double precision,text)','EXECUTE'));
select pg_temp.qa_check('authenticated role retains search execute permission',
  has_function_privilege('authenticated','public.rpc_search_nearby_drivers(double precision,double precision,text,text,integer)','EXECUTE'));

select pg_temp.qa_identity('viewer');
set local role authenticated;
select pg_temp.qa_check('verified viewer sees online but not offline fixture coordinates',(
  select count(*)=1 and bool_and(driver_id=(select user_id from pg_temp.qa_discovery_actors where name='driver'))
  from public.driver_locations where driver_id in (select user_id from pg_temp.qa_discovery_actors)
));
select pg_temp.qa_check('verified search includes the online fixture and excludes offline fixture',(
  select count(*)=1 and bool_and(driver_id=(select user_id from pg_temp.qa_discovery_actors where name='driver'))
  from public.rpc_search_nearby_drivers(0,0,null,'cab',1000)
  where driver_id in (select user_id from pg_temp.qa_discovery_actors)
));
select pg_temp.qa_check('verified summary preserves vehicle-filtered counts',
  (public.rpc_get_discover_summary(null,null,'cab')->>'nearby_driver_count')::bigint
    = (select online_cabs+1 from pg_temp.qa_discovery_baseline));
reset role;

select pg_temp.qa_identity('offline');
set local role authenticated;
select pg_temp.qa_check('verified driver can read its own offline location', exists(
  select 1 from public.driver_locations where driver_id=auth.uid() and not is_online
));
reset role;
select pg_temp.qa_identity('admin');
set local role authenticated;
select pg_temp.qa_check('qualified Admin retains offline location visibility',(
  select count(*)=2 from public.driver_locations
  where driver_id in (select user_id from pg_temp.qa_discovery_actors)
));
reset role;
update public.admin_whatsapp_numbers set is_active=false where phone_e164='+250700006104';
set local role authenticated;
select pg_temp.qa_discovery_denied('deactivated Admin');
reset role;
update public.admin_whatsapp_numbers set is_active=true where phone_e164='+250700006104';

select pg_temp.qa_identity('anonymous');
set local role authenticated;
select pg_temp.qa_discovery_denied('anonymous bootstrap');
reset role;
select pg_temp.qa_identity('unverified');
set local role authenticated;
select pg_temp.qa_discovery_denied('unverified Auth account');
reset role;
select pg_temp.qa_identity('viewer');
update auth.sessions set not_after=now()
where id=(select session_id from qa_discovery_actors where name='viewer');
set local role authenticated;
select pg_temp.qa_discovery_denied('expired verified session');
reset role;
delete from auth.sessions where id=(select session_id from qa_discovery_actors where name='viewer');
set local role authenticated;
select pg_temp.qa_discovery_denied('revoked verified session');
reset role;

select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select pg_temp.qa_check('trusted server role retains discovery search', exists(
  select 1 from public.rpc_search_nearby_drivers(0,0,null,'cab',1000)
  where driver_id=(select user_id from pg_temp.qa_discovery_actors where name='driver')
));
select pg_temp.qa_check('trusted server role retains summary counts',
  (public.rpc_get_discover_summary(null,null,'cab')->>'nearby_driver_count')::bigint
    = (select online_cabs+1 from pg_temp.qa_discovery_baseline));
reset role;

select name as passed_assertion from qa_discovery_results order by name;
select count(*) as passed_assertions from qa_discovery_results;
rollback;
