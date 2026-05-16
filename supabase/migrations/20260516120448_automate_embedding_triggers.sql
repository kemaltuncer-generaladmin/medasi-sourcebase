
-- Grant pg_net usage to the postgres role
GRANT USAGE ON SCHEMA net TO postgres;

-- Define the trigger function to call the embedding service
CREATE OR REPLACE FUNCTION sourcebase.trigger_embed_content()
RETURNS TRIGGER AS $$
DECLARE
    text_content TEXT;
    table_name TEXT;
BEGIN
    table_name := TG_TABLE_NAME;

    -- Determine the text content based on the table
    IF table_name = 'sources' THEN
        text_content := NEW.text_content;
    ELSIF table_name = 'cards' THEN
        text_content := NEW.front;
    ELSE
        -- If the table is not recognized, do nothing
        RETURN NEW;
    END IF;

    -- If the text content is null or empty, do nothing
    IF text_content IS NULL OR text_content = '' THEN
        RETURN NEW;
    END IF;

    -- Asynchronously call the edge function to embed and store the content
    PERFORM net.http_post(
        url:=(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url') || '/functions/v1/ai-services',
        headers:=jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_anon_key')
        ),
        body:=jsonb_build_object(
            'action', 'embed-and-store',
            'payload', jsonb_build_object(
                'tableName', table_name,
                'recordId', NEW.id,
                'text', text_content
            )
        ),
        timeout_milliseconds:=2000
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger for the 'sources' table
CREATE TRIGGER on_source_change
AFTER INSERT OR UPDATE ON sourcebase.sources
FOR EACH ROW
EXECUTE FUNCTION sourcebase.trigger_embed_content();

-- Create the trigger for the 'cards' table
CREATE TRIGGER on_card_change
AFTER INSERT OR UPDATE ON sourcebase.cards
FOR EACH ROW
EXECUTE FUNCTION sourcebase.trigger_embed_content();
