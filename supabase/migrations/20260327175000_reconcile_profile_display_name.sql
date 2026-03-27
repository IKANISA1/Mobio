begin;

alter table public.profiles
  add column if not exists display_name text;

update public.profiles
set display_name = name
where display_name is null
  and coalesce(name, '') <> '';

commit;
