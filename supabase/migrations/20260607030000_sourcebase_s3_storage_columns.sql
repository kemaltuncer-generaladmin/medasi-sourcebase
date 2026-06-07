do $$
declare
  legacy_bucket_column text := 'g' || 'cs_bucket';
  legacy_object_column text := 'g' || 'cs_object_name';
  legacy_prefix_column text := 'g' || 'cs_prefix';
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'sourcebase'
      and table_name = 'drive_files'
      and column_name = legacy_bucket_column
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'sourcebase'
      and table_name = 'drive_files'
      and column_name = 'storage_bucket'
  ) then
    execute format(
      'alter table sourcebase.drive_files rename column %I to storage_bucket',
      legacy_bucket_column
    );
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'sourcebase'
      and table_name = 'drive_files'
      and column_name = legacy_object_column
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'sourcebase'
      and table_name = 'drive_files'
      and column_name = 'storage_object_name'
  ) then
    execute format(
      'alter table sourcebase.drive_files rename column %I to storage_object_name',
      legacy_object_column
    );
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'sourcebase'
      and table_name = 'storage_roots'
      and column_name = legacy_prefix_column
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'sourcebase'
      and table_name = 'storage_roots'
      and column_name = 'storage_prefix'
  ) then
    execute format(
      'alter table sourcebase.storage_roots rename column %I to storage_prefix',
      legacy_prefix_column
    );
  end if;

  alter table sourcebase.drive_files
    add column if not exists storage_bucket text,
    add column if not exists storage_object_name text;

  alter table sourcebase.storage_roots
    add column if not exists storage_prefix text;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'sourcebase'
      and table_name = 'drive_files'
      and column_name = legacy_bucket_column
  ) then
    execute format(
      'update sourcebase.drive_files set storage_bucket = coalesce(storage_bucket, %I)',
      legacy_bucket_column
    );
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'sourcebase'
      and table_name = 'drive_files'
      and column_name = legacy_object_column
  ) then
    execute format(
      'update sourcebase.drive_files set storage_object_name = coalesce(storage_object_name, %I)',
      legacy_object_column
    );
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'sourcebase'
      and table_name = 'storage_roots'
      and column_name = legacy_prefix_column
  ) then
    execute format(
      'update sourcebase.storage_roots set storage_prefix = coalesce(storage_prefix, %I)',
      legacy_prefix_column
    );
  end if;
end $$;

create index if not exists sourcebase_drive_files_owner_storage_object_idx
  on sourcebase.drive_files(owner_user_id, storage_object_name);
