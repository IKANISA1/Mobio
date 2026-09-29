-- Restricted, read-only operator review before body 04 on a representative
-- forward-upgrade copy. Output contains account UUIDs and must stay private.
-- Review financial/external references before approving any account-level map.
begin transaction read only;

select 'invalid_nonnull' as issue, count(*) as affected_rows
from public.profiles
where member_id is not null and member_id !~ '^[0-9]{6}$'
union all
select 'duplicate_values', count(*)
from (
  select member_id from public.profiles
  where member_id is not null
  group by member_id having count(*) > 1
) duplicates
union all
select 'unassigned_null', count(*)
from public.profiles where member_id is null;

select member_id, count(*) as affected_rows, array_agg(id order by created_at nulls last,id) as account_ids
from public.profiles
where member_id is not null
group by member_id having count(*) > 1
order by member_id;

select id as account_id, member_id as invalid_value
from public.profiles
where member_id is not null and member_id !~ '^[0-9]{6}$'
order by id;

-- Candidate relational references; also review JSON, exported reports, operator
-- records and references outside this database before changing a public ID.
select table_schema, table_name, column_name, data_type
from information_schema.columns
where table_schema in ('public','mobio_private')
  and (column_name like '%member_id%' or column_name = 'agent_id')
order by table_schema, table_name, column_name;

rollback;
