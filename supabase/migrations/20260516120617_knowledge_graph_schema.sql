
-- Create the schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS sourcebase;

-- Enable the vector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create the concepts table
CREATE TABLE sourcebase.concepts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    embedding VECTOR(768)
);

-- Create the concept_relationships table
CREATE TABLE sourcebase.concept_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_concept_id UUID NOT NULL REFERENCES sourcebase.concepts(id) ON DELETE CASCADE,
    target_concept_id UUID REFERENCES sourcebase.concepts(id) ON DELETE CASCADE,
    target_entity_type TEXT,
    target_entity_id UUID,
    relationship_type TEXT NOT NULL,
    CONSTRAINT chk_target CHECK (
        (target_concept_id IS NOT NULL AND target_entity_id IS NULL AND target_entity_type IS NULL)
        OR
        (target_concept_id IS NULL AND target_entity_id IS NOT NULL AND target_entity_type IS NOT NULL)
    )
);

-- Create indexes for performance
-- Indexes on foreign keys are often created automatically, but we'll ensure they exist.
CREATE INDEX ON sourcebase.concept_relationships (source_concept_id);
CREATE INDEX ON sourcebase.concept_relationships (target_concept_id);
CREATE INDEX ON sourcebase.concept_relationships (target_entity_id);

-- Create a HNSW index on the embedding column for fast similarity search
CREATE INDEX ON sourcebase.concepts USING hnsw (embedding vector_l2_ops);

