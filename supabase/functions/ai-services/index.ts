import { corsHeaders } from "../_shared/cors.ts";
import { supabaseAdmin } from "../_shared/supabase-client.ts";
import { VertexAIClient } from "../sourcebase/services/vertex-ai.ts";
import { isRecord, SafeError } from "../sourcebase/types.ts";

type AuthContext =
  | { kind: "service"; userId: null }
  | { kind: "user"; userId: string };

const MAX_TEXT_CHARS = 120_000;
const MAX_QUERY_CHARS = 2_000;
const EMBEDDABLE_TABLES = new Set(["sources", "cards"]);
const CONCEPT_ENTITY_TYPES = new Set(["source", "card", "drive_file"]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      throw new SafeError(
        "METHOD_NOT_ALLOWED",
        "Bu işlem desteklenmiyor.",
        405,
      );
    }

    const body = await req.json().catch(() => ({}));
    if (!isRecord(body)) {
      throw new SafeError("INVALID_PAYLOAD", "İstek gövdesi geçersiz.", 400);
    }

    const action = body.action?.toString().trim() ?? "";
    const payload = isRecord(body.payload) ? body.payload : {};
    const auth = await authenticate(req);

    switch (action) {
      case "embed-and-store":
        requireServiceAuth(auth);
        return jsonSuccess(
          await embedAndStore(supabaseAdmin, createVertexAIClient(), payload),
        );
      case "find-similar":
        requireUserAuth(auth);
        return jsonSuccess(
          await findSimilar(
            supabaseAdmin,
            createVertexAIClient(),
            auth.userId,
            payload,
          ),
        );
      case "extract-concepts":
        return jsonSuccess(
          await extractConcepts(
            supabaseAdmin,
            createVertexAIClient(),
            auth,
            payload,
          ),
        );
      default:
        throw new SafeError(
          "UNKNOWN_ACTION",
          "Bilinmeyen bir eylem istendi.",
          400,
        );
    }
  } catch (error) {
    const safeError = error instanceof SafeError
      ? error
      : new SafeError("INTERNAL_ERROR", "Bir sunucu hatası oluştu.", 500);
    console.error("AI services error:", safeError.code, safeError.status);
    return jsonFailure(safeError);
  }
});

async function authenticate(req: Request): Promise<AuthContext> {
  const authorization = req.headers.get("authorization") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ??
    "";
  if (serviceRoleKey && authorization === `Bearer ${serviceRoleKey}`) {
    return { kind: "service", userId: null };
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";
  if (!supabaseUrl || !anonKey) {
    throw new SafeError(
      "AUTH_NOT_CONFIGURED",
      "Kimlik doğrulama yapılandırılmamış.",
      500,
    );
  }
  if (!authorization) {
    throw new SafeError("UNAUTHORIZED", "Oturum gerekli.", 401);
  }

  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { authorization, apikey: anonKey },
  });
  if (!response.ok) {
    throw new SafeError("UNAUTHORIZED", "Oturum doğrulanamadı.", 401);
  }
  const user = await response.json();
  const userId = user?.id?.toString() ?? "";
  if (!userId) {
    throw new SafeError("UNAUTHORIZED", "Oturum doğrulanamadı.", 401);
  }
  return { kind: "user", userId };
}

function requireServiceAuth(auth: AuthContext): asserts auth is {
  kind: "service";
  userId: null;
} {
  if (auth.kind !== "service") {
    throw new SafeError(
      "FORBIDDEN",
      "Bu işlem backend yetkisi gerektirir.",
      403,
    );
  }
}

function requireUserAuth(auth: AuthContext): asserts auth is {
  kind: "user";
  userId: string;
} {
  if (auth.kind !== "user") {
    throw new SafeError("UNAUTHORIZED", "Kullanıcı oturumu gerekli.", 401);
  }
}

async function embedAndStore(
  supabase: typeof supabaseAdmin,
  vertexAI: VertexAIClient,
  payload: Record<string, unknown>,
) {
  const tableName = requireText(payload.tableName, "tableName", 40);
  const recordId = requireText(payload.recordId, "recordId", 80);
  const text = requireText(payload.text, "text", MAX_TEXT_CHARS);
  if (!EMBEDDABLE_TABLES.has(tableName)) {
    throw new SafeError("INVALID_TABLE", "Embedding hedefi geçersiz.", 400);
  }

  const { embedding } = await vertexAI.generateEmbedding(text, {
    taskType: "RETRIEVAL_DOCUMENT",
  });

  const { data, error } = await supabase
    .from(tableName)
    .update({ embedding: vectorLiteral(embedding) })
    .eq("id", recordId)
    .select("id")
    .single();

  if (error || !data?.id) {
    console.error("Embedding update failed:", error?.code ?? "no_row");
    throw new SafeError(
      "DB_UPDATE_FAILED",
      "Kayıt güncellenirken bir hata oluştu.",
      500,
    );
  }

  return { success: true, recordId: data.id };
}

async function extractConcepts(
  supabase: typeof supabaseAdmin,
  vertexAI: VertexAIClient,
  auth: AuthContext,
  payload: Record<string, unknown>,
) {
  const textContent = requireText(
    payload.textContent,
    "textContent",
    MAX_TEXT_CHARS,
  );
  const entityId = requireText(payload.entityId, "entityId", 80);
  const entityType = normalizeEntityType(
    requireText(payload.entityType, "entityType", 40),
  );

  if (auth.kind === "user") {
    await assertEntityOwned(supabase, auth.userId, entityType, entityId);
  }

  const { content: extracted } = await vertexAI.generateConcepts(textContent);
  const concepts = Array.isArray(extracted.concepts) ? extracted.concepts : [];
  const relationships = Array.isArray(extracted.relationships)
    ? extracted.relationships
    : [];

  if (concepts.length === 0) {
    throw new SafeError(
      "CONCEPT_EXTRACTION_EMPTY",
      "AI modelinden kavram çıkarılamadı.",
      500,
    );
  }

  const conceptIds = new Map<string, string>();
  for (const concept of concepts.slice(0, 20)) {
    if (!isRecord(concept)) continue;
    const name = concept.name?.toString().trim().slice(0, 160) ?? "";
    const description = concept.description?.toString().trim().slice(0, 1000) ??
      "";
    if (!name) continue;

    const { data: existingConcept, error: selectError } = await supabase
      .from("concepts")
      .select("id")
      .eq("name", name)
      .limit(1)
      .maybeSingle();
    if (selectError) {
      throw new SafeError("DB_SELECT_FAILED", "Kavramlar okunamadı.", 500);
    }
    if (existingConcept?.id) {
      conceptIds.set(name, existingConcept.id);
      continue;
    }

    const { embedding } = await vertexAI.generateEmbedding(
      `${name}: ${description}`,
      { taskType: "RETRIEVAL_DOCUMENT" },
    );
    const { data: newConcept, error: insertError } = await supabase
      .from("concepts")
      .insert({
        name,
        description,
        embedding: vectorLiteral(embedding),
      })
      .select("id")
      .single();
    if (insertError || !newConcept?.id) {
      throw new SafeError("DB_INSERT_FAILED", "Kavram kaydedilemedi.", 500);
    }
    conceptIds.set(name, newConcept.id);
  }

  const relationshipsToInsert: Record<string, unknown>[] = [];
  for (const rel of relationships.slice(0, 50)) {
    if (!isRecord(rel)) continue;
    const sourceId = conceptIds.get(rel.source?.toString().trim() ?? "");
    const targetId = conceptIds.get(rel.target?.toString().trim() ?? "");
    if (sourceId && targetId) {
      relationshipsToInsert.push({
        source_concept_id: sourceId,
        target_concept_id: targetId,
        relationship_type: safeRelationshipType(rel.type),
      });
    }
  }

  for (const conceptId of conceptIds.values()) {
    relationshipsToInsert.push({
      source_concept_id: conceptId,
      target_entity_type: entityType,
      target_entity_id: entityId,
      relationship_type: "MENTIONS",
    });
  }

  if (relationshipsToInsert.length > 0) {
    const { error } = await supabase
      .from("concept_relationships")
      .insert(relationshipsToInsert);
    if (error) {
      console.error("Concept relationship insert failed:", error.code);
      throw new SafeError(
        "DB_INSERT_FAILED",
        "Kavram ilişkileri kaydedilemedi.",
        500,
      );
    }
  }

  return { success: true, createdConcepts: Array.from(conceptIds.keys()) };
}

async function findSimilar(
  supabase: typeof supabaseAdmin,
  vertexAI: VertexAIClient,
  userId: string,
  payload: Record<string, unknown>,
) {
  const queryText = requireText(
    payload.queryText,
    "queryText",
    MAX_QUERY_CHARS,
  );
  const limit = boundedInteger(payload.limit, 10, 1, 30, "limit");
  const { embedding: queryEmbedding } = await vertexAI.generateEmbedding(
    queryText,
    { taskType: "RETRIEVAL_QUERY" },
  );

  const { data, error } = await supabase.rpc("find_similar_sources_and_cards", {
    query_embedding: vectorLiteral(queryEmbedding),
    match_threshold: 0.7,
    match_count: limit,
    match_user_id: userId,
  });

  if (error) {
    console.error("Similarity RPC failed:", error.code);
    throw new SafeError(
      "DB_RPC_FAILED",
      "Benzer sonuçlar aranırken bir hata oluştu.",
      500,
    );
  }

  return { success: true, results: Array.isArray(data) ? data : [] };
}

async function assertEntityOwned(
  supabase: typeof supabaseAdmin,
  userId: string,
  entityType: string,
  entityId: string,
) {
  if (entityType === "source") {
    const { data } = await supabase
      .from("sources")
      .select("id")
      .eq("id", entityId)
      .eq("owner_user_id", userId)
      .limit(1)
      .maybeSingle();
    if (data?.id) return;
  }
  if (entityType === "drive_file") {
    const { data } = await supabase
      .from("drive_files")
      .select("id")
      .eq("id", entityId)
      .eq("owner_user_id", userId)
      .limit(1)
      .maybeSingle();
    if (data?.id) return;
  }
  if (entityType === "card") {
    const { data } = await supabase
      .from("cards")
      .select("id, decks!inner(owner_user_id)")
      .eq("id", entityId)
      .eq("decks.owner_user_id", userId)
      .limit(1)
      .maybeSingle();
    if (data?.id) return;
  }
  throw new SafeError("NOT_FOUND", "Kayıt bulunamadı veya yetkin yok.", 404);
}

function createVertexAIClient(): VertexAIClient {
  const projectId = Deno.env.get("VERTEX_PROJECT_ID")?.trim() ?? "";
  const location = Deno.env.get("VERTEX_LOCATION")?.trim() ?? "us-central1";
  const model = Deno.env.get("VERTEX_MODEL")?.trim() ?? "gemini-2.5-flash";
  const serviceAccountJson =
    Deno.env.get("VERTEX_SERVICE_ACCOUNT_JSON")?.trim() ??
      "";

  if (!projectId || !serviceAccountJson) {
    throw new SafeError(
      "VERTEX_CONFIG_MISSING",
      "Vertex AI yapılandırması eksik.",
      500,
    );
  }

  return new VertexAIClient({
    projectId,
    location,
    model,
    serviceAccountJson,
  });
}

function requireText(value: unknown, name: string, maxLength: number) {
  const text = value?.toString().trim() ?? "";
  if (!text) {
    throw new SafeError("INVALID_PAYLOAD", `${name} alanı zorunludur.`, 400);
  }
  if (text.length > maxLength) {
    throw new SafeError("INVALID_PAYLOAD", `${name} çok uzun.`, 400);
  }
  return text;
}

function boundedInteger(
  value: unknown,
  fallback: number,
  min: number,
  max: number,
  name: string,
) {
  const numberValue = value === undefined || value === null || value === ""
    ? fallback
    : Number(value);
  if (
    !Number.isInteger(numberValue) || numberValue < min || numberValue > max
  ) {
    throw new SafeError("INVALID_PAYLOAD", `${name} geçersiz.`, 400);
  }
  return numberValue;
}

function normalizeEntityType(entityType: string) {
  const normalized = entityType.trim();
  if (!CONCEPT_ENTITY_TYPES.has(normalized)) {
    throw new SafeError("INVALID_ENTITY_TYPE", "Kavram hedefi geçersiz.", 400);
  }
  return normalized;
}

function safeRelationshipType(value: unknown) {
  const text = value?.toString().trim().toUpperCase() ?? "";
  return /^[A-Z_]{2,40}$/.test(text) ? text : "RELATED_TO";
}

function vectorLiteral(values: number[]) {
  return `[${values.map((value) => Number(value).toFixed(8)).join(",")}]`;
}

function jsonSuccess(data: unknown, status = 200) {
  return json({ ok: true, data }, status);
}

function jsonFailure(error: SafeError) {
  return json(
    { ok: false, error: { code: error.code, message: error.message } },
    error.status,
  );
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}
