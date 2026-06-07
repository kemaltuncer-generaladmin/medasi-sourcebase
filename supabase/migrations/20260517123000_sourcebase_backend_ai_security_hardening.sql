-- SourceBase backend/AI security hardening.
-- This migration is additive/non-destructive: it tightens RLS ownership checks,
-- aligns AI job types with the backend, and moves internal embedding calls off anon auth.

create extension if not exists vector;

alter table if exists sourcebase.sources
  add column if not exists embedding vector(768);

alter table if exists sourcebase.cards
  add column if not exists embedding vector(768);

create index if not exists sourcebase_sources_embedding_idx
  on sourcebase.sources using ivfflat (embedding vector_cosine_ops) with (lists = 100);

create index if not exists sourcebase_cards_embedding_idx
  on sourcebase.cards using ivfflat (embedding vector_cosine_ops) with (lists = 100);

alter table if exists sourcebase.generated_jobs
  drop constraint if exists generated_jobs_job_type_check;

update sourcebase.generated_jobs
set job_type = case job_type
  when 'flashcards' then 'flashcard'
  when 'questions' then 'quiz'
  when 'question' then 'quiz'
  when 'notes' then 'summary'
  when 'outline' then 'summary'
  when 'clinicalScenario' then 'clinical_scenario'
  when 'learningPlan' then 'learning_plan'
  when 'mindMap' then 'mind_map'
  else job_type
end
where job_type in (
  'flashcards',
  'questions',
  'question',
  'notes',
  'outline',
  'clinicalScenario',
  'learningPlan',
  'mindMap'
);

alter table if exists sourcebase.generated_jobs
  add constraint generated_jobs_job_type_check
  check (
    job_type in (
      'flashcard',
      'quiz',
      'summary',
      'algorithm',
      'comparison',
      'podcast',
      'clinical_scenario',
      'learning_plan',
      'infographic',
      'mind_map'
    )
  );

drop policy if exists "sourcebase_sections_owner_all" on sourcebase.sections;
create policy "sourcebase_sections_owner_all"
  on sourcebase.sections for all
  using (owner_user_id = auth.uid())
  with check (
    owner_user_id = auth.uid()
    and exists (
      select 1
      from sourcebase.courses
      where courses.id = sections.course_id
        and courses.owner_user_id = auth.uid()
    )
  );

drop policy if exists "sourcebase_drive_files_owner_all" on sourcebase.drive_files;
create policy "sourcebase_drive_files_owner_all"
  on sourcebase.drive_files for all
  using (owner_user_id = auth.uid())
  with check (
    owner_user_id = auth.uid()
    and (
      course_id is null
      or exists (
        select 1
        from sourcebase.courses
        where courses.id = drive_files.course_id
          and courses.owner_user_id = auth.uid()
      )
    )
    and (
      section_id is null
      or exists (
        select 1
        from sourcebase.sections
        where sections.id = drive_files.section_id
          and sections.owner_user_id = auth.uid()
          and (
            drive_files.course_id is null
            or sections.course_id = drive_files.course_id
          )
      )
    )
  );

drop policy if exists "sourcebase_generated_outputs_owner_all"
  on sourcebase.generated_outputs;
create policy "sourcebase_generated_outputs_owner_all"
  on sourcebase.generated_outputs for all
  using (
    owner_user_id = auth.uid()
    and exists (
      select 1
      from sourcebase.drive_files
      where drive_files.id = generated_outputs.source_file_id
        and drive_files.owner_user_id = auth.uid()
    )
  )
  with check (
    owner_user_id = auth.uid()
    and exists (
      select 1
      from sourcebase.drive_files
      where drive_files.id = generated_outputs.source_file_id
        and drive_files.owner_user_id = auth.uid()
    )
  );

drop policy if exists "sourcebase_generated_jobs_owner_all"
  on sourcebase.generated_jobs;
create policy "sourcebase_generated_jobs_owner_all"
  on sourcebase.generated_jobs for all
  using (owner_user_id = auth.uid())
  with check (
    owner_user_id = auth.uid()
    and (
      source_file_id is null
      or exists (
        select 1
        from sourcebase.drive_files
        where drive_files.id = generated_jobs.source_file_id
          and drive_files.owner_user_id = auth.uid()
      )
    )
    and (
      source_id is null
      or exists (
        select 1
        from sourcebase.sources
        where sources.id = generated_jobs.source_id
          and sources.owner_user_id = auth.uid()
      )
    )
    and (
      deck_id is null
      or exists (
        select 1
        from sourcebase.decks
        where decks.id = generated_jobs.deck_id
          and decks.owner_user_id = auth.uid()
      )
    )
  );

alter table if exists sourcebase.concepts enable row level security;
alter table if exists sourcebase.concept_relationships enable row level security;

create or replace function sourcebase.find_similar_sources_and_cards(
  query_embedding vector(768),
  match_threshold float,
  match_count int,
  match_user_id uuid
)
returns table (
  id uuid,
  type text,
  title text,
  similarity float
)
language plpgsql
security definer
set search_path = sourcebase, public
as $$
begin
  return query
  with combined_results as (
    select
      s.id,
      'source'::text as type,
      coalesce(s.title, s.original_filename, 'Kaynak') as title,
      1 - (s.embedding <=> query_embedding) as similarity
    from sourcebase.sources s
    where s.owner_user_id = match_user_id
      and s.embedding is not null
      and 1 - (s.embedding <=> query_embedding) > match_threshold

    union all

    select
      c.id,
      'card'::text as type,
      c.front as title,
      1 - (c.embedding <=> query_embedding) as similarity
    from sourcebase.cards c
    join sourcebase.decks d on d.id = c.deck_id
    where d.owner_user_id = match_user_id
      and c.embedding is not null
      and 1 - (c.embedding <=> query_embedding) > match_threshold
  )
  select
    combined_results.id,
    combined_results.type,
    combined_results.title,
    combined_results.similarity
  from combined_results
  order by combined_results.similarity desc
  limit least(greatest(match_count, 1), 30);
end;
$$;

grant execute on function sourcebase.find_similar_sources_and_cards(
  vector(768),
  float,
  int,
  uuid
) to authenticated, service_role;

create or replace function public.find_similar_sources_and_cards(
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
returns table (
  id uuid,
  type text,
  title text,
  similarity float
)
language sql
security invoker
as $$
  select *
  from sourcebase.find_similar_sources_and_cards(
    query_embedding,
    match_threshold,
    match_count,
    auth.uid()
  )
  where auth.uid() is not null;
$$;

revoke execute on function public.find_similar_sources_and_cards(
  vector(768),
  float,
  int
) from anon;

grant execute on function public.find_similar_sources_and_cards(
  vector(768),
  float,
  int
) to authenticated;

create or replace function sourcebase.trigger_embed_content()
returns trigger as $$
declare
    text_content text;
    table_name text;
begin
    table_name := TG_TABLE_NAME;

    if table_name = 'sources' then
        text_content := NEW.text_content;
    elsif table_name = 'cards' then
        text_content := NEW.front;
    else
        return NEW;
    end if;

    if text_content is null or btrim(text_content) = '' then
        return NEW;
    end if;

    perform net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name = 'supabase_url') || '/functions/v1/ai-services',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'supabase_service_role_key')
        ),
        body := jsonb_build_object(
            'action', 'embed-and-store',
            'payload', jsonb_build_object(
                'tableName', table_name,
                'recordId', NEW.id,
                'text', text_content
            )
        ),
        timeout_milliseconds := 2000
    );

    return NEW;
end;
$$ language plpgsql;

do $$
begin
    if to_regclass('sourcebase.sources') is not null
       and not exists (
          select 1 from pg_trigger
          where tgname = 'on_source_change'
            and tgrelid = to_regclass('sourcebase.sources')
       ) then
        create trigger on_source_change
        after insert or update on sourcebase.sources
        for each row
        execute function sourcebase.trigger_embed_content();
    end if;

    if to_regclass('sourcebase.cards') is not null
       and not exists (
          select 1 from pg_trigger
          where tgname = 'on_card_change'
            and tgrelid = to_regclass('sourcebase.cards')
       ) then
        create trigger on_card_change
        after insert or update on sourcebase.cards
        for each row
        execute function sourcebase.trigger_embed_content();
    end if;
end $$;

notify pgrst, 'reload schema';
