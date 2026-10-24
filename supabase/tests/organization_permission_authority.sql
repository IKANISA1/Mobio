-- Disposable full-schema database only. Actual application policies and RPCs,
-- real Auth/session rows, and SQL authenticated role; all fixtures roll back.
-- Synthetic JWT claims do not prove OTP delivery or JWT signature verification.
-- Run with psql -v ON_ERROR_STOP=1 after the real migration chain.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create temp table qa_org_actors (
  name text primary key,
  org_role text,
  phone text not null,
  provider text not null default 'whatsapp_cloud_otp',
  user_id uuid not null default gen_random_uuid(),
  session_id uuid not null default gen_random_uuid()
);
insert into qa_org_actors(name,org_role,phone) values
  ('owner','owner','+250700008101'),
  ('admin','admin','+250700008102'),
  ('manager','manager','+250700008103'),
  ('driver','driver','+250700008104'),
  ('member','member','+250700008105'),
  ('viewer','viewer','+250700008106'),
  ('other-passenger',null,'+250700008107');
insert into qa_org_actors(name,phone,provider) values
  ('delegated-admin','+250700008108','admin_whatsapp_otp'),
  ('full-admin','+250700008109','admin_whatsapp_otp');
create temp table qa_org_context (
  own_org uuid not null default gen_random_uuid(),
  other_org uuid not null default gen_random_uuid(),
  agency_id uuid not null default gen_random_uuid(),
  route_id uuid not null default gen_random_uuid(),
  schedule_id uuid not null default gen_random_uuid()
);
insert into qa_org_context default values;
create temp table qa_org_bookings (
  name text primary key,
  booking_id uuid not null default gen_random_uuid()
);
insert into qa_org_bookings(name) values ('owned'),('victim'),('delegated'),('fallback');
create temp table qa_org_results(name text);
grant select on qa_org_actors,qa_org_context,qa_org_bookings to authenticated;
grant select,insert on qa_org_results to authenticated;

create function pg_temp.qa_org_check(label text,value boolean) returns void
language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'ASSERTION FAILED: %',label;
  end if;
  insert into pg_temp.qa_org_results values(label);
end;
$$;
create function pg_temp.qa_org_identity(actor text) returns void
language plpgsql as $$
declare claims jsonb;
begin
  select jsonb_build_object('sub',user_id,'session_id',session_id,
    'role','authenticated','is_anonymous',false,
    'app_metadata',jsonb_build_object('provider',provider))
  into strict claims from pg_temp.qa_org_actors where name=actor;
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims',claims::text,true);
end;
$$;
create function pg_temp.qa_org_confirmation_denied(label text,requires_reauthentication boolean default false) returns void
language plpgsql as $$
begin
  begin
    perform 1 from public.rpc_confirm_bus_booking(
      (select booking_id from pg_temp.qa_org_bookings where name='victim'),
      'qa-organization-authority',label,'{"qa_fixture":true}'::jsonb);
    raise exception 'ASSERTION FAILED: real booking confirmation accepted %',label;
  exception when sqlstate 'P0001' then
    if requires_reauthentication or sqlerrm <> 'Payment confirmation requires agency or service authorization.' then
      raise;
    end if;
    perform pg_temp.qa_org_check(label||': actual confirmation RPC denied',true);
  when sqlstate '42501' then
    if not requires_reauthentication or sqlerrm <> 'ADMIN_REAUTHENTICATION_REQUIRED' then
      raise;
    end if;
    perform pg_temp.qa_org_check(label||': exact reauthentication denial',true);
  end;
end;
$$;

insert into auth.users(id,phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,is_anonymous)
select user_id,phone,now(),jsonb_build_object('provider',provider),
  '{"qa_fixture":true}',false from qa_org_actors;
insert into auth.sessions(id,user_id,created_at,not_after)
select session_id,user_id,now(),now()+interval '1 hour' from qa_org_actors;
-- Explicit SQL-only positive OTP/session setup; no Admin lease or grant is added.
select pg_temp.qa_seed_interactive_authority(array(select user_id from qa_org_actors));

-- Auth's existing profile trigger creates the authoritative profile/member ID.
update public.profiles set role='admin'
where id=(select user_id from qa_org_actors where name='full-admin');
-- The delegated Admin stays a passenger profile: the explicit grant, rather
-- than the full-admin profile fallback, must be what authorizes this identity.
insert into public.admin_whatsapp_numbers(phone_e164,country_code,display_name,is_active)
select phone,'+250','Synthetic organization authority administrator',true
from qa_org_actors where name in ('delegated-admin','full-admin');
insert into mobio_private.admin_session_leases
  (session_id,user_id,otp_id,authenticated_at,last_activity_at,idle_expires_at,absolute_expires_at)
select session_id,user_id,'organization-authority-'||name,now(),now(),
  now()+interval '15 minutes',now()+interval '8 hours'
from qa_org_actors where name in ('delegated-admin','full-admin');
insert into public.profile_platform_permissions(profile_id,permission_key,expires_at)
select user_id,'transport.bookings.manage',now()+interval '5 minutes'
from qa_org_actors where name='delegated-admin';
-- A grant attached to a consumer cannot establish the separate Admin purpose.
insert into public.profile_platform_permissions(profile_id,permission_key)
select user_id,'transport.bookings.manage' from qa_org_actors where name='member';

insert into public.organizations(id,slug,name,status)
select own_org,'qa-org-authority-own','Synthetic own organization','active' from qa_org_context
union all
select other_org,'qa-org-authority-other','Synthetic unrelated organization','active' from qa_org_context;
insert into public.organization_members(organization_id,profile_id,org_role,status)
select c.own_org,a.user_id,a.org_role,'active'
from qa_org_context c cross join qa_org_actors a where a.org_role is not null;
insert into public.transport_agencies(id,organization_id,name,slug,is_active)
select agency_id,own_org,'Synthetic organization agency','qa-org-authority-agency',false from qa_org_context;
insert into public.transport_routes(id,agency_id,organization_id,route_code,origin_name,destination_name)
select route_id,agency_id,own_org,'QA-ORG','Synthetic origin','Synthetic destination' from qa_org_context;
insert into public.bus_schedules(id,agency_id,route_id,organization_id,departure_at,fare_amount,currency,status)
select schedule_id,agency_id,route_id,own_org,now()+interval '1 day',1000,'RWF','scheduled' from qa_org_context;
insert into public.bus_seat_inventory(schedule_id,organization_id,total_seats,available_seats,held_seats,confirmed_seats)
select schedule_id,own_org,10,6,4,0 from qa_org_context;
insert into public.bus_bookings(id,schedule_id,agency_id,organization_id,passenger_id,
  seat_count,status,payment_status,amount,currency,hold_expires_at,ticket_reference)
select b.booking_id,c.schedule_id,c.agency_id,c.own_org,a.user_id,
  1,'held','pending',1000,'RWF',now()+interval '10 minutes','QA-ORG-'||b.name
from qa_org_context c cross join qa_org_bookings b
join qa_org_actors a on a.name=case when b.name='owned' then 'member' else 'other-passenger' end;

create temp table qa_org_initial_bookings as
select id,to_jsonb(b) as row_value from public.bus_bookings b
where id in (select booking_id from qa_org_bookings where name in ('owned','victim'));
create temp table qa_org_initial_inventory as
select to_jsonb(i) as row_value from public.bus_seat_inventory i
where schedule_id=(select schedule_id from qa_org_context);
create temp table qa_org_initial_payments as
select coalesce(jsonb_agg(to_jsonb(p) order by p.id),'[]'::jsonb) as rows_value
from public.bus_booking_payments p where organization_id=(select own_org from qa_org_context);

-- Keep this first: the old 119-migration schema must fail on the REAL payment
-- transition, not merely on a boolean helper or a synthetic replacement RPC.
select pg_temp.qa_org_identity('member');
set local role authenticated;
select pg_temp.qa_org_confirmation_denied('ordinary member with consumer platform grant');
reset role;
select pg_temp.qa_org_check('denied confirmation leaves victim and owned booking byte-for-byte unchanged',
  not exists(select 1 from qa_org_initial_bookings old_row
    left join public.bus_bookings b on b.id=old_row.id
    where b.id is null or to_jsonb(b) is distinct from old_row.row_value));
select pg_temp.qa_org_check('denied confirmation leaves receipt rows unchanged',
  (select coalesce(jsonb_agg(to_jsonb(p) order by p.id),'[]'::jsonb)
   from public.bus_booking_payments p where organization_id=(select own_org from qa_org_context))
    = (select rows_value from qa_org_initial_payments));
select pg_temp.qa_org_check('denied confirmation leaves inventory byte-for-byte unchanged',
  (select to_jsonb(i) from public.bus_seat_inventory i where schedule_id=(select schedule_id from qa_org_context))
    = (select row_value from qa_org_initial_inventory));

set local role authenticated;
do $$
declare actor record; permission_key text;
begin
  for actor in select name from pg_temp.qa_org_actors where org_role is not null order by name loop
    perform pg_temp.qa_org_identity(actor.name);
    perform pg_temp.qa_org_check(actor.name||': real verified consumer identity retained',
      public.verified_app_user_id()=auth.uid());
    foreach permission_key in array array['platform.admin','transport.agencies.manage',
      'transport.bookings.manage','transport.tracking.ingest','ev_chargers.manage'] loop
      perform pg_temp.qa_org_check(actor.name||': membership denies '||permission_key,
        not public.can_access_organization((select own_org from pg_temp.qa_org_context),permission_key));
    end loop;
    perform pg_temp.qa_org_check(actor.name||': null intent permits own organization read',
      public.can_access_organization((select own_org from pg_temp.qa_org_context),null));
    perform pg_temp.qa_org_check(actor.name||': default intent remains membership read',
      public.can_access_organization((select own_org from pg_temp.qa_org_context)));
    perform pg_temp.qa_org_check(actor.name||': unrelated organization read denied',
      not public.can_access_organization((select other_org from pg_temp.qa_org_context),null));
    perform pg_temp.qa_org_check(actor.name||': actual organization RLS retains own root',
      exists(select 1 from public.organizations where id=(select own_org from pg_temp.qa_org_context)));
    perform pg_temp.qa_org_check(actor.name||': actual organization RLS hides unrelated root',
      not exists(select 1 from public.organizations where id=(select other_org from pg_temp.qa_org_context)));
    perform pg_temp.qa_org_check(actor.name||': actual membership RLS retains own row',
      exists(select 1 from public.organization_members
        where organization_id=(select own_org from pg_temp.qa_org_context) and profile_id=auth.uid()));
    perform pg_temp.qa_org_check(actor.name||': membership alone cannot enumerate other members',
      not exists(select 1 from public.organization_members
        where organization_id=(select own_org from pg_temp.qa_org_context) and profile_id<>auth.uid()));
    perform pg_temp.qa_org_check(actor.name||': other passenger booking hidden by real RLS',
      not exists(select 1 from public.bus_bookings
        where id=(select booking_id from pg_temp.qa_org_bookings where name='victim')));
    perform pg_temp.qa_org_confirmation_denied(actor.name||' organization role');
  end loop;
end;
$$;
select pg_temp.qa_org_identity('member');
select pg_temp.qa_org_check('owner retains own held booking through real RLS',exists(
  select 1 from public.bus_bookings where id=(select booking_id from qa_org_bookings where name='owned')
));
select pg_temp.qa_org_check('owner retains own payment status through real RPC',(
  select count(*)=1 and bool_and(payment_status='pending')
  from public.rpc_get_bus_payment_status((select booking_id from qa_org_bookings where name='owned'))
));
select pg_temp.qa_org_check('other passenger payment status is not returned by real RPC',not exists(
  select 1 from public.rpc_get_bus_payment_status((select booking_id from qa_org_bookings where name='victim'))
));
reset role;
select pg_temp.qa_org_check('all role denials leave held bookings unchanged',
  not exists(select 1 from qa_org_initial_bookings old_row
    left join public.bus_bookings b on b.id=old_row.id
    where b.id is null or to_jsonb(b) is distinct from old_row.row_value));
select pg_temp.qa_org_check('all role denials leave no fabricated receipt',
  not exists(select 1 from public.bus_booking_payments where organization_id=(select own_org from qa_org_context)));
select pg_temp.qa_org_check('all role denials retain exact seat inventory',
  (select to_jsonb(i) from public.bus_seat_inventory i where schedule_id=(select schedule_id from qa_org_context))
    = (select row_value from qa_org_initial_inventory));

select pg_temp.qa_org_identity('delegated-admin');
set local role authenticated;
select pg_temp.qa_org_check('trusted delegated Admin with lease retains exact booking permission',
  public.can_access_organization((select own_org from qa_org_context),'transport.bookings.manage'));
select pg_temp.qa_org_check('trusted delegated Admin is not granted agency management',
  not public.can_access_organization((select own_org from qa_org_context),'transport.agencies.manage'));
select pg_temp.qa_org_check('global explicit grant retains its existing cross-organization scope',
  public.can_access_organization((select other_org from qa_org_context),'transport.bookings.manage'));
select pg_temp.qa_org_check('actual confirmation succeeds for trusted explicit Admin grant',(
  select count(*)=1 and bool_and(status='confirmed' and payment_status='paid')
  from public.rpc_confirm_bus_booking(
    (select booking_id from qa_org_bookings where name='delegated'),
    'qa-organization-authority','trusted-delegated-receipt','{"qa_fixture":true}'::jsonb)
));
reset role;
select pg_temp.qa_org_check('trusted delegated confirmation persists a bound paid receipt',exists(
  select 1 from public.bus_booking_payments
  where booking_id=(select booking_id from qa_org_bookings where name='delegated')
    and provider_reference='trusted-delegated-receipt' and status='paid' and amount=1000 and currency='RWF'
));
update public.profile_platform_permissions set expires_at=now()-interval '1 second'
where profile_id=(select user_id from qa_org_actors where name='delegated-admin');
set local role authenticated;
select pg_temp.qa_org_check('expired delegated grant denies management despite live lease',
  not public.can_access_organization((select own_org from qa_org_context),'transport.bookings.manage'));
select pg_temp.qa_org_confirmation_denied('expired delegated grant');
reset role;
update public.profile_platform_permissions set expires_at=null
where profile_id=(select user_id from qa_org_actors where name='delegated-admin');
update mobio_private.admin_session_leases set revoked_at=now()
where user_id=(select user_id from qa_org_actors where name='delegated-admin');
set local role authenticated;
select pg_temp.qa_org_check('revoked Admin lease denies nonexpiring explicit grant',
  not public.can_access_organization((select own_org from qa_org_context),'transport.bookings.manage'));
select pg_temp.qa_org_confirmation_denied('revoked delegated Admin lease',true);
reset role;

-- No explicit grant may mask the existing full-admin fallback under test.
delete from public.profile_platform_permissions
where profile_id=(select user_id from qa_org_actors where name='full-admin');
select pg_temp.qa_org_identity('full-admin');
set local role authenticated;
select pg_temp.qa_org_check('trusted full Admin fallback with active lease retains booking authority',
  public.can_access_organization((select own_org from qa_org_context),'transport.bookings.manage'));
select pg_temp.qa_org_check('trusted full Admin fallback retains other management authority',
  public.can_access_organization((select own_org from qa_org_context),'transport.agencies.manage'));
select pg_temp.qa_org_check('trusted full Admin retains cross-organization null/read authority',
  public.can_access_organization((select other_org from qa_org_context),null));
select pg_temp.qa_org_check('actual confirmation succeeds for trusted full Admin fallback',(
  select count(*)=1 and bool_and(status='confirmed' and payment_status='paid')
  from public.rpc_confirm_bus_booking(
    (select booking_id from qa_org_bookings where name='fallback'),
    'qa-organization-authority','trusted-full-admin-receipt','{"qa_fixture":true}'::jsonb)
));
reset role;
update mobio_private.admin_session_leases set idle_expires_at=now()-interval '1 second'
where user_id=(select user_id from qa_org_actors where name='full-admin');
set local role authenticated;
select pg_temp.qa_org_check('expired lease denies full-admin fallback',
  not public.can_access_organization((select own_org from qa_org_context),'transport.bookings.manage'));
select pg_temp.qa_org_confirmation_denied('expired full Admin lease',true);
reset role;
update mobio_private.admin_session_leases set idle_expires_at=now()+interval '15 minutes',revoked_at=now()
where user_id=(select user_id from qa_org_actors where name='full-admin');
set local role authenticated;
select pg_temp.qa_org_check('revoked lease denies full-admin fallback',
  not public.can_access_organization((select own_org from qa_org_context),'transport.bookings.manage'));
select pg_temp.qa_org_confirmation_denied('revoked full Admin lease',true);
reset role;

select pg_temp.qa_org_check('all rejected authority transitions retain victim and owned bookings',
  not exists(select 1 from qa_org_initial_bookings old_row
    join public.bus_bookings b on b.id=old_row.id where to_jsonb(b) is distinct from old_row.row_value));
select pg_temp.qa_org_check('only the two trusted confirmations persist paid receipts',(
  select count(*)=2 and bool_and(provider_reference in ('trusted-delegated-receipt','trusted-full-admin-receipt')
    and status='paid') from public.bus_booking_payments where organization_id=(select own_org from qa_org_context)
));
select pg_temp.qa_org_check('seat inventory records exactly two trusted confirmations and conserves total',(
  select total_seats=10 and available_seats=6 and held_seats=2 and confirmed_seats=2
    and available_seats+held_seats+confirmed_seats=total_seats
  from public.bus_seat_inventory where schedule_id=(select schedule_id from qa_org_context)
));
select pg_temp.qa_org_check('ordinary booking table and column write authority remains revoked',
  not has_table_privilege('authenticated','public.bus_bookings','INSERT,UPDATE,DELETE,TRUNCATE')
  and not has_any_column_privilege('authenticated','public.bus_bookings','INSERT')
  and not has_any_column_privilege('authenticated','public.bus_bookings','UPDATE'));

select name as passed_assertion from qa_org_results order by name;
select count(*) as passed_assertions from qa_org_results;
rollback;
