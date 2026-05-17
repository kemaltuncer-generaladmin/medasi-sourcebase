create table if not exists sourcebase.storage_roots (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  root_key text not null,
  title text not null,
  gcs_prefix text not null,
  status text not null default 'active',
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_user_id, root_key)
);

create index if not exists sourcebase_storage_roots_owner_idx
  on sourcebase.storage_roots(owner_user_id);

alter table sourcebase.storage_roots enable row level security;

drop policy if exists "sourcebase_storage_roots_owner_select"
  on sourcebase.storage_roots;
create policy "sourcebase_storage_roots_owner_select"
  on sourcebase.storage_roots for select
  using (owner_user_id = auth.uid());

drop policy if exists "sourcebase_storage_roots_owner_insert"
  on sourcebase.storage_roots;
create policy "sourcebase_storage_roots_owner_insert"
  on sourcebase.storage_roots for insert
  with check (owner_user_id = auth.uid());

drop policy if exists "sourcebase_storage_roots_owner_update"
  on sourcebase.storage_roots;
create policy "sourcebase_storage_roots_owner_update"
  on sourcebase.storage_roots for update
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

grant all on table sourcebase.storage_roots to anon, authenticated, service_role;
