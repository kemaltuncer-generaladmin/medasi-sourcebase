-- Allow BaseForce Sınav Sabahı Özeti jobs to use the backend-supported
-- exam_morning_summary generation type.

alter table if exists sourcebase.generated_jobs
  drop constraint if exists generated_jobs_job_type_check;

alter table if exists sourcebase.generated_jobs
  add constraint generated_jobs_job_type_check
  check (
    job_type in (
      'flashcard',
      'quiz',
      'summary',
      'exam_morning_summary',
      'algorithm',
      'comparison',
      'podcast',
      'clinical_scenario',
      'learning_plan',
      'infographic',
      'mind_map'
    )
  );
