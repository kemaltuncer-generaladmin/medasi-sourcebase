create schema if not exists sourcebase;

create table if not exists sourcebase.courses (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  icon_name text,
  subject text,
  status text not null default 'active',
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists sourcebase.sections (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  course_id uuid not null references sourcebase.courses(id) on delete cascade,
  title text not null,
  status text not null default 'active',
  sort_order integer not null default 0,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists sourcebase.drive_files (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  course_id uuid references sourcebase.courses(id) on delete set null,
  section_id uuid references sourcebase.sections(id) on delete set null,
  title text not null,
  file_type text not null,
  original_filename text not null,
  gcs_bucket text,
  gcs_object_name text,
  mime_type text,
  size_bytes bigint,
  page_count integer,
  status text not null default 'uploaded',
  ai_status text not null default 'pending',
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists sourcebase.generated_outputs (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  source_file_id uuid not null references sourcebase.drive_files(id) on delete cascade,
  output_type text not null,
  title text not null,
  item_count integer,
  status text not null default 'ready',
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists sourcebase.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists sourcebase_courses_owner_idx
  on sourcebase.courses(owner_user_id);

create index if not exists sourcebase_sections_owner_course_idx
  on sourcebase.sections(owner_user_id, course_id);

create index if not exists sourcebase_drive_files_owner_course_section_idx
  on sourcebase.drive_files(owner_user_id, course_id, section_id);

create index if not exists sourcebase_generated_outputs_owner_file_idx
  on sourcebase.generated_outputs(owner_user_id, source_file_id);

alter table sourcebase.courses enable row level security;
alter table sourcebase.sections enable row level security;
alter table sourcebase.drive_files enable row level security;
alter table sourcebase.generated_outputs enable row level security;
alter table sourcebase.audit_logs enable row level security;

drop policy if exists "sourcebase_courses_owner_select" on sourcebase.courses;
create policy "sourcebase_courses_owner_select"
  on sourcebase.courses for select
  using (owner_user_id = auth.uid());

drop policy if exists "sourcebase_courses_owner_insert" on sourcebase.courses;
create policy "sourcebase_courses_owner_insert"
  on sourcebase.courses for insert
  with check (owner_user_id = auth.uid());

drop policy if exists "sourcebase_courses_owner_update" on sourcebase.courses;
create policy "sourcebase_courses_owner_update"
  on sourcebase.courses for update
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

drop policy if exists "sourcebase_sections_owner_all" on sourcebase.sections;
create policy "sourcebase_sections_owner_all"
  on sourcebase.sections for all
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

drop policy if exists "sourcebase_drive_files_owner_all" on sourcebase.drive_files;
create policy "sourcebase_drive_files_owner_all"
  on sourcebase.drive_files for all
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

drop policy if exists "sourcebase_generated_outputs_owner_all" on sourcebase.generated_outputs;
create policy "sourcebase_generated_outputs_owner_all"
  on sourcebase.generated_outputs for all
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

drop policy if exists "sourcebase_audit_logs_owner_select" on sourcebase.audit_logs;
create policy "sourcebase_audit_logs_owner_select"
  on sourcebase.audit_logs for select
  using (actor_user_id = auth.uid());

drop policy if exists "sourcebase_audit_logs_owner_insert" on sourcebase.audit_logs;
create policy "sourcebase_audit_logs_owner_insert"
  on sourcebase.audit_logs for insert
  with check (actor_user_id = auth.uid());
