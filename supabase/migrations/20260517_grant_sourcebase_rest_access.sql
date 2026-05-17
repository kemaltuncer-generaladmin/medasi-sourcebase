grant usage on schema sourcebase to anon, authenticated, service_role;

grant select, insert, update, delete
  on all tables in schema sourcebase
  to anon, authenticated, service_role;

grant usage, select
  on all sequences in schema sourcebase
  to anon, authenticated, service_role;

alter default privileges in schema sourcebase
  grant select, insert, update, delete
  on tables
  to anon, authenticated, service_role;

alter default privileges in schema sourcebase
  grant usage, select
  on sequences
  to anon, authenticated, service_role;

notify pgrst, 'reload schema';
