-- Enable the pgvector extension
create extension if not exists vector;

-- Add the embedding column to the sources table
alter table sourcebase.sources
add column embedding vector(768);

-- Add the embedding column to the cards table
alter table sourcebase.cards
add column embedding vector(768);

-- Create indexes for fast search on the new columns
create index on sourcebase.sources using ivfflat (embedding vector_cosine_ops) with (lists = 100);
create index on sourcebase.cards using ivfflat (embedding vector_cosine_ops) with (lists = 100);
