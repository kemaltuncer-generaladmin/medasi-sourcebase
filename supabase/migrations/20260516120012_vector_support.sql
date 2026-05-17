-- Enable the pgvector extension
create extension if not exists vector;

-- The 20260516 timestamped migrations may be applied before
-- 20260516_complete_sourcebase_schema.sql in fresh shadow databases. Keep this
-- migration non-failing and let the later hardening migration guarantee columns.
do $$
begin
  if to_regclass('sourcebase.sources') is not null then
    alter table sourcebase.sources
      add column if not exists embedding vector(768);

    create index if not exists sourcebase_sources_embedding_idx
      on sourcebase.sources using ivfflat (embedding vector_cosine_ops) with (lists = 100);
  end if;

  if to_regclass('sourcebase.cards') is not null then
    alter table sourcebase.cards
      add column if not exists embedding vector(768);

    create index if not exists sourcebase_cards_embedding_idx
      on sourcebase.cards using ivfflat (embedding vector_cosine_ops) with (lists = 100);
  end if;
end $$;
