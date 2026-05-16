-- SourceBase generated_jobs AI compatibility fix
-- Date: 2026-05-16
-- Purpose: Align generated_jobs with the Edge Function AI job processor.

alter table sourcebase.generated_jobs
  add column if not exists source_file_id uuid references sourcebase.drive_files(id) on delete set null;

alter table sourcebase.generated_jobs
  drop constraint if exists generated_jobs_job_type_check;

update sourcebase.generated_jobs
set job_type = case job_type
  when 'flashcards' then 'flashcard'
  when 'questions' then 'quiz'
  when 'notes' then 'summary'
  when 'outline' then 'summary'
  else job_type
end
where job_type in ('flashcards', 'questions', 'notes', 'outline');

alter table sourcebase.generated_jobs
  add constraint generated_jobs_job_type_check
  check (job_type in ('flashcard', 'quiz', 'summary', 'algorithm', 'comparison', 'podcast'));

create index if not exists sourcebase_generated_jobs_source_file_idx
  on sourcebase.generated_jobs(source_file_id);

create index if not exists sourcebase_generated_jobs_owner_status_idx
  on sourcebase.generated_jobs(owner_user_id, status);

create index if not exists sourcebase_generated_jobs_created_idx
  on sourcebase.generated_jobs(created_at desc);
