--
-- Semantic Search RPC Function
--
-- Bu fonksiyon, hem `sources` hem de `cards` tablolarında anlamsal arama yapar
-- ve sonuçları birleştirerek döndürür.
--
CREATE OR REPLACE FUNCTION find_similar_sources_and_cards(
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id uuid,
  type text,
  title text,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH combined_results AS (
    -- Search in sources table
    SELECT
      s.id,
      'source' AS type,
      s.title,
      1 - (s.embedding <=> query_embedding) AS similarity
    FROM
      sources s
    WHERE
      s.embedding IS NOT NULL AND 1 - (s.embedding <=> query_embedding) > match_threshold

    UNION ALL

    -- Search in cards table
    SELECT
      c.id,
      'card' AS type,
      c.front AS title, -- Using front content as title for cards
      1 - (c.embedding <=> query_embedding) AS similarity
    FROM
      cards c
    WHERE
      c.embedding IS NOT NULL AND 1 - (c.embedding <=> query_embedding) > match_threshold
  )
  SELECT
    cr.id,
    cr.type,
    cr.title,
    cr.similarity
  FROM
    combined_results cr
  ORDER BY
    cr.similarity DESC
  LIMIT
    match_count;
END;
$$;
