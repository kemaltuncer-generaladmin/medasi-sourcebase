
import "@supabase/functions-js/edge-runtime.d.ts";
import { supabaseAdmin } from "../_shared/supabase-client.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { VertexAIClient } from "../sourcebase/services/vertex-ai.ts";
import { SafeError } from "../sourcebase/types.ts";

// --- Main Request Handler ---
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { action, payload } = body;

    const vertexAIClient = createVertexAIClient();

    switch (action) {
      case "embed-and-store":
        return json(await embedAndStore(supabaseAdmin, vertexAIClient, payload));
      case "find-similar":
        return json(await findSimilar(supabaseAdmin, vertexAIClient, payload));
      case "extract-concepts":
        return json(await extractConcepts(supabaseAdmin, vertexAIClient, payload));
      default:
        throw new SafeError("UNKNOWN_ACTION", "Bilinmeyen bir eylem istendi.", 400);
    }
  } catch (error) {
    console.error("Function Error:", error);
    const safeError = error instanceof SafeError ? error : new SafeError("INTERNAL_ERROR", "Bir sunucu hatası oluştu.", 500);
    return json({ error: { code: safeError.code, message: safeError.message } }, safeError.status);
  }
});

// --- Action: Embed and Store ---
async function embedAndStore(
  supabase: any,
  vertexAI: VertexAIClient,
  payload: any,
) {
  const { tableName, recordId, text } = payload;
  if (!tableName || !recordId || !text) {
    throw new SafeError("INVALID_PAYLOAD", "tableName, recordId, ve text alanları zorunludur.", 400);
  }

  const { embedding } = await vertexAI.generateEmbedding(text, {
    taskType: "RETRIEVAL_DOCUMENT",
  });

  if (!embedding || embedding.length === 0) {
    throw new SafeError("EMBEDDING_FAILED", "Metin için vektör oluşturulamadı.", 500);
  }

  const { data, error } = await supabase
    .from(tableName)
    .update({ embedding: `[${embedding.join(",")}]` })
    .eq("id", recordId)
    .select("id")
    .single();

  if (error) {
    console.error("Supabase Update Error:", error);
    throw new SafeError("DB_UPDATE_FAILED", "Kayıt güncellenirken bir hata oluştu.", 500);
  }

  return { success: true, recordId: data.id };
}

// --- Action: Extract Concepts ---
async function extractConcepts(
  supabase: any,
  vertexAI: VertexAIClient,
  payload: any,
) {
  const { textContent, entityId, entityType } = payload;
  if (!textContent || !entityId || !entityType) {
    throw new SafeError("INVALID_PAYLOAD", "textContent, entityId, ve entityType alanları zorunludur.", 400);
  }

  const { content: extracted, costEstimate } = await vertexAI.generateConcepts(textContent);
  const { concepts, relationships } = extracted;

  if (!concepts || !relationships) {
    throw new SafeError("CONCEPT_EXTRACTION_FAILED", "AI modelinden kavramlar ve ilişkiler çıkarılamadı.", 500);
  }

  const { data, error } = await supabase.from("ai_usage_logs").insert({ 
      action: 'extract-concepts',
      payload: payload,
      cost_estimate: costEstimate,
      tokens: 0, // Bu bilgiyi Vertex SDK'dan almak lazım
  });

  if(error) console.error('Error logging AI usage:', error);


  const { data: trxData, error: trxError } = await supabase.tx(async (tx: any) => {
    const conceptIds = new Map<string, string>();

    for (const concept of concepts) {
      let { data: existingConcept } = await tx.from("concepts").select("id").eq("name", concept.name).maybeSingle();

      if (existingConcept) {
        conceptIds.set(concept.name, existingConcept.id);
      } else {
        const { embedding } = await vertexAI.generateEmbedding(concept.name + ": " + concept.description, {
            taskType: "RETRIEVAL_DOCUMENT",
        });

        if (!embedding || embedding.length === 0) {
            console.error(`Embedding for concept \"${concept.name}\" could not be generated.`);
            continue; 
        }

        const { data: newConcept, error: insertError } = await tx.from("concepts").insert({
            name: concept.name,
            description: concept.description,
            embedding: `[${embedding.join(",")}]`
        }).select("id").single();

        if (insertError) throw insertError;
        conceptIds.set(concept.name, newConcept.id);
      }
    }

    const relationshipsToInsert = [];

    for (const rel of relationships) {
      const sourceId = conceptIds.get(rel.source);
      const targetId = conceptIds.get(rel.target);
      if (sourceId && targetId) {
        relationshipsToInsert.push({
          source_concept_id: sourceId,
          target_concept_id: targetId,
          relationship_type: rel.type,
        });
      }
    }

    for (const [_, conceptId] of conceptIds) {
      relationshipsToInsert.push({
        source_concept_id: conceptId,
        [entityType + "_id"]: entityId, 
        relationship_type: "MENTIONS",
      });
    }

    if(relationshipsToInsert.length > 0){
        const { error: relError } = await tx.from("concept_relationships").insert(relationshipsToInsert);
        if (relError) throw relError;
    }

    return { concepts: Array.from(conceptIds.keys()) };
  });

  if (trxError) {
    console.error("Transaction Error:", trxError);
    throw new SafeError("DB_TRANSACTION_FAILED", "Veritabanı işlemleri sırasında bir hata oluştu.", 500);
  }

  return { success: true, created_concepts: trxData.concepts };
}

// --- Action: Find Similar ---
async function findSimilar(
  supabase: any,
  vertexAI: VertexAIClient,
  payload: any,
) {
  const { queryText, limit = 10 } = payload;
  if (!queryText) {
    throw new SafeError("INVALID_PAYLOAD", "queryText alanı zorunludur.", 400);
  }

  const { embedding: queryEmbedding } = await vertexAI.generateEmbedding(queryText, {
    taskType: "RETRIEVAL_QUERY",
  });

  if (!queryEmbedding || queryEmbedding.length === 0) {
    throw new SafeError("EMBEDDING_FAILED", "Sorgu için vektör oluşturulamadı.", 500);
  }

  const { data, error } = await supabase.rpc("find_similar_sources_and_cards", {
    query_embedding: `[${queryEmbedding.join(",")}]`,
    match_threshold: 0.7,
    match_count: limit,
  });

  if (error) {
    console.error("Supabase RPC Error:", error);
    throw new SafeError("DB_RPC_FAILED", "Benzer sonuçlar aranırken bir hata oluştu.", 500);
  }

  return { success: true, results: data };
}


// --- Utility Functions ---

function createVertexAIClient(): VertexAIClient {
    const projectId = Deno.env.get("VERTEX_PROJECT_ID");
    const location = Deno.env.get("VERTEX_LOCATION");
    const serviceAccountJson = Deno.env.get("VERTEX_SERVICE_ACCOUNT_JSON");

    if (!projectId || !location || !serviceAccountJson) {
        throw new SafeError("VERTEX_CONFIG_MISSING", "Vertex AI yapılandırması eksik.", 500);
    }

    return new VertexAIClient({
        projectId,
        location,
        model: "gemini-1.5-pro-preview-0409", 
        serviceAccountJson,
    });
}

function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}
