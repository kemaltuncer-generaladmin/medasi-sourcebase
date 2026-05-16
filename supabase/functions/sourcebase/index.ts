import { SafeError, isRecord } from "./types.ts";
import {
  processFileExtraction,
  createGenerationJob,
  getJobStatus,
  getGeneratedContent,
  listUserJobs,
  cancelJob,
  retryJob,
} from "./actions/ai-generation.ts";

type JsonMap = Record<string, unknown>;

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("SOURCEBASE_ALLOWED_ORIGIN") ??
    "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (request.method !== "POST") {
      return failure("METHOD_NOT_ALLOWED", "Bu işlem desteklenmiyor.", 405);
    }

    const body = await request.json().catch(() => ({}));
    const action = String(body.action ?? "");
    const payload = isRecord(body.payload) ? body.payload : {};
    const user = await authenticate(request);

    switch (action) {
      // Drive actions
      case "drive_bootstrap":
        return success(await driveBootstrap(user.id));
      case "create_course":
        return success(await createCourse(user.id, payload));
      case "create_section":
        return success(await createSection(user.id, payload));
      case "create_upload_session":
        return success(await createUploadSession(user.id, payload));
      case "complete_upload":
        return success(await completeUpload(user.id, payload));
      case "create_generated_output":
        return success(await createGeneratedOutput(user.id, payload));
      
      // AI Generation actions
      case "process_file_extraction":
        return success(await processFileExtraction(user.id, payload));
      case "create_generation_job":
        return success(await createGenerationJob(user.id, payload));
      case "get_job_status":
        return success(await getJobStatus(user.id, payload));
      case "get_generated_content":
        return success(await getGeneratedContent(user.id, payload));
      case "list_user_jobs":
        return success(await listUserJobs(user.id, payload));
      case "cancel_job":
        return success(await cancelJob(user.id, payload));
      case "retry_job":
        return success(await retryJob(user.id, payload));
      
      default:
        return failure("UNKNOWN_ACTION", "SourceBase işlemi bulunamadı.", 400);
    }
  } catch (error) {
    const message = error instanceof SafeError
      ? error.message
      : "İşlem tamamlanamadı.";
    const code = error instanceof SafeError ? error.code : "INTERNAL_ERROR";
    const status = error instanceof SafeError ? error.status : 500;
    return failure(code, message, status);
  }
});

async function authenticate(
  request: Request,
): Promise<{ id: string; email?: string }> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const authorization = request.headers.get("authorization");

  if (!supabaseUrl || !anonKey) {
    throw new SafeError(
      "AUTH_NOT_CONFIGURED",
      "SourceBase kimlik doğrulama yapılandırılmamış.",
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
  if (!user?.id) {
    throw new SafeError("UNAUTHORIZED", "Oturum doğrulanamadı.", 401);
  }
  return { id: String(user.id), email: user.email?.toString() };
}

async function driveBootstrap(userId: string) {
  await ensureDefaultWorkspace(userId);
  const [courses, sections, files, generatedOutputs] = await Promise.all([
    dbSelect(
      `courses?owner_user_id=eq.${userId}&select=*&order=created_at.asc`,
    ),
    dbSelect(
      `sections?owner_user_id=eq.${userId}&select=*&order=sort_order.asc,created_at.asc`,
    ),
    dbSelect(
      `drive_files?owner_user_id=eq.${userId}&select=*&order=created_at.desc`,
    ),
    dbSelect(
      `generated_outputs?owner_user_id=eq.${userId}&select=*&order=created_at.desc`,
    ),
  ]);
  return {
    storage: {
      provider: "gcs",
      bucketConfigured: Boolean(Deno.env.get("SOURCEBASE_GCS_BUCKET")),
    },
    courses,
    sections,
    files,
    generatedOutputs,
  };
}

async function ensureDefaultWorkspace(userId: string) {
  const existing = await dbSelect(
    `courses?owner_user_id=eq.${userId}&select=id&limit=1`,
  );
  if (existing.length > 0) {
    return;
  }
  const [course] = await dbInsert("courses", [{
    owner_user_id: userId,
    title: "Kardiyoloji",
    icon_name: "heart",
    subject: "Kardiyoloji",
    status: "active",
    metadata: {
      description:
        "Kardiyoloji dersine ait tüm içerikler, bölümler halinde düzenlenmiştir.",
    },
  }]);
  const courseId = String(course.id ?? "");
  if (!courseId) return;
  await dbInsert("sections", [
    {
      owner_user_id: userId,
      course_id: courseId,
      title: "Aritmiler",
      status: "active",
      sort_order: 1,
    },
    {
      owner_user_id: userId,
      course_id: courseId,
      title: "Kalp Yetmezliği",
      status: "active",
      sort_order: 2,
    },
    {
      owner_user_id: userId,
      course_id: courseId,
      title: "Kapak Hastalıkları",
      status: "draft",
      sort_order: 3,
    },
  ]);
}

async function createCourse(userId: string, payload: JsonMap) {
  const title = requireString(payload.title, "title");
  const [row] = await dbInsert("courses", [{
    owner_user_id: userId,
    title,
    icon_name: "book",
    subject: title,
    status: "active",
    metadata: {
      description: `${title} dersine ait içerikler için yeni alan hazır.`,
    },
  }]);
  await audit(userId, "create_course", "course", row.id, { title });
  return { row };
}

async function createSection(userId: string, payload: JsonMap) {
  const courseId = requireString(payload.courseId, "courseId");
  const title = requireString(payload.title, "title");
  await assertOwned(userId, "courses", courseId);
  const [row] = await dbInsert("sections", [{
    owner_user_id: userId,
    course_id: courseId,
    title,
    status: "active",
  }]);
  await audit(userId, "create_section", "section", row.id, { courseId, title });
  return { row };
}

async function createUploadSession(userId: string, payload: JsonMap) {
  const fileName = requireString(payload.fileName, "fileName");
  const contentType = requireString(payload.contentType, "contentType");
  const courseId = requireString(payload.courseId, "courseId");
  const sectionId = requireString(payload.sectionId, "sectionId");
  const sizeBytes = Number(payload.sizeBytes ?? 0);

  if (
    !Number.isFinite(sizeBytes) || sizeBytes <= 0 ||
    sizeBytes > 100 * 1024 * 1024
  ) {
    throw new SafeError(
      "INVALID_FILE_SIZE",
      "Dosya boyutu SourceBase yükleme sınırları dışında.",
      400,
    );
  }

  const bucket = Deno.env.get("SOURCEBASE_GCS_BUCKET");
  const serviceJson = Deno.env.get("SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON");
  if (!bucket || !serviceJson) {
    throw new SafeError(
      "GCS_NOT_CONFIGURED",
      "GCS yükleme ayarları tamamlanmamış.",
      500,
    );
  }

  const safeName = sanitizeFileName(fileName);
  const sourceId = crypto.randomUUID();
  const objectName = `user/${userId}/sources/${sourceId}/${safeName}`;
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
  const uploadUrl = await createGcsV4SignedPutUrl({
    bucket,
    objectName,
    contentType,
    serviceAccountJson: serviceJson,
    expiresInSeconds: 900,
  });

  return {
    uploadUrl,
    objectName,
    bucket,
    expiresAt: expiresAt.toISOString(),
    headers: { "Content-Type": contentType },
    metadata: { sourceId, courseId, sectionId },
  };
}

async function completeUpload(userId: string, payload: JsonMap) {
  const objectName = requireString(payload.objectName, "objectName");
  const courseId = requireString(payload.courseId, "courseId");
  const sectionId = requireString(payload.sectionId, "sectionId");
  const fileName = requireString(payload.fileName, "fileName");
  const contentType = requireString(payload.contentType, "contentType");
  const sizeBytes = Number(payload.sizeBytes ?? 0);
  if (!objectName.startsWith(`user/${userId}/sources/`)) {
    throw new SafeError("FORBIDDEN_OBJECT", "Dosya yolu yetkili değil.", 403);
  }
  await assertOwned(userId, "courses", courseId);
  await assertOwned(userId, "sections", sectionId);
  const bucket = Deno.env.get("SOURCEBASE_GCS_BUCKET") ?? "";
  const [row] = await dbInsert("drive_files", [{
    owner_user_id: userId,
    course_id: courseId,
    section_id: sectionId,
    title: fileName,
    file_type: fileKind(fileName),
    original_filename: fileName,
    gcs_bucket: bucket,
    gcs_object_name: objectName,
    mime_type: contentType,
    size_bytes: Number.isFinite(sizeBytes) ? sizeBytes : null,
    page_count: null,
    status: "uploaded",
    ai_status: "processing",
    metadata: {},
  }]);
  await audit(userId, "complete_upload", "drive_file", row.id, {
    courseId,
    sectionId,
    objectName,
  });

  return {
    row,
    objectName,
    status: "uploaded",
    nextAction: "extract_and_analyze",
  };
}

async function createGeneratedOutput(userId: string, payload: JsonMap) {
  const fileId = requireString(payload.fileId, "fileId");
  const kind = requireString(payload.kind, "kind");
  await assertOwned(userId, "drive_files", fileId);
  const [row] = await dbInsert("generated_outputs", [{
    owner_user_id: userId,
    source_file_id: fileId,
    output_type: kind,
    title: generatedTitle(kind),
    item_count: generatedCount(kind),
    status: "ready",
    metadata: { mode: "manual_request" },
  }]);
  await audit(userId, "create_generated_output", "generated_output", row.id, {
    fileId,
    kind,
  });
  return { row };
}

async function assertOwned(userId: string, table: string, id: string) {
  const rows = await dbSelect(
    `${table}?id=eq.${id}&owner_user_id=eq.${userId}&select=id&limit=1`,
  );
  if (rows.length === 0) {
    throw new SafeError("NOT_FOUND", "Kayıt bulunamadı veya yetkin yok.", 404);
  }
}

async function dbSelect(path: string): Promise<JsonMap[]> {
  const response = await supabaseRest(path, { method: "GET" });
  const data = await response.json();
  return Array.isArray(data) ? data.filter(isRecord) : [];
}

async function dbInsert(table: string, rows: JsonMap[]): Promise<JsonMap[]> {
  const response = await supabaseRest(table, {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify(rows),
  });
  const data = await response.json();
  if (Array.isArray(data)) {
    return data.filter(isRecord);
  }
  return [];
}

async function audit(
  userId: string,
  action: string,
  entityType: string,
  entityId: unknown,
  metadata: JsonMap,
) {
  await dbInsert("audit_logs", [{
    actor_user_id: userId,
    action,
    entity_type: entityType,
    entity_id: typeof entityId === "string" ? entityId : null,
    metadata,
  }]);
}

async function supabaseRest(path: string, init: RequestInit) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    throw new SafeError(
      "DATABASE_NOT_CONFIGURED",
      "SourceBase veritabanı yapılandırılmamış.",
      500,
    );
  }
  const response = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: serviceKey,
      authorization: `Bearer ${serviceKey}`,
      "content-type": "application/json",
      "accept-profile": "sourcebase",
      "content-profile": "sourcebase",
      ...(init.headers ?? {}),
    },
  });
  if (!response.ok) {
    throw new SafeError("DATABASE_ERROR", "SourceBase verisi işlenemedi.", 500);
  }
  return response;
}

async function createGcsV4SignedPutUrl(input: {
  bucket: string;
  objectName: string;
  contentType: string;
  serviceAccountJson: string;
  expiresInSeconds: number;
}) {
  const serviceAccount = JSON.parse(input.serviceAccountJson);
  const clientEmail = String(serviceAccount.client_email ?? "");
  const privateKey = String(serviceAccount.private_key ?? "");
  if (!clientEmail || !privateKey) {
    throw new SafeError(
      "GCS_SERVICE_ACCOUNT_INVALID",
      "GCS service JSON geçersiz.",
      500,
    );
  }

  const now = new Date();
  const date = formatDate(now);
  const timestamp = `${date}T${formatTime(now)}Z`;
  const scope = `${date}/auto/storage/goog4_request`;
  const credential = `${clientEmail}/${scope}`;
  const canonicalUri = `/${encodePath(input.bucket)}/${
    encodePath(input.objectName)
  }`;
  const query: Record<string, string> = {
    "X-Goog-Algorithm": "GOOG4-RSA-SHA256",
    "X-Goog-Credential": credential,
    "X-Goog-Date": timestamp,
    "X-Goog-Expires": String(input.expiresInSeconds),
    "X-Goog-SignedHeaders": "content-type;host",
  };
  const canonicalQuery = canonicalQueryString(query);
  const canonicalHeaders =
    `content-type:${input.contentType}\nhost:storage.googleapis.com\n`;
  const canonicalRequest = [
    "PUT",
    canonicalUri,
    canonicalQuery,
    canonicalHeaders,
    "content-type;host",
    "UNSIGNED-PAYLOAD",
  ].join("\n");
  const stringToSign = [
    "GOOG4-RSA-SHA256",
    timestamp,
    scope,
    await sha256Hex(canonicalRequest),
  ].join("\n");
  const signature = await rsaSha256(privateKey, stringToSign);
  return `https://storage.googleapis.com${canonicalUri}?${canonicalQuery}&X-Goog-Signature=${signature}`;
}

function success(data: unknown) {
  return json({ ok: true, data });
}

function failure(code: string, message: string, status = 400) {
  return json({ ok: false, error: { code, message } }, status);
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json; charset=utf-8",
    },
  });
}

function isRecord(value: unknown): value is JsonMap {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireString(value: unknown, name: string) {
  const text = value?.toString().trim() ?? "";
  if (!text) {
    throw new SafeError("INVALID_PAYLOAD", `${name} alanı zorunlu.`, 400);
  }
  return text;
}

function sanitizeFileName(fileName: string) {
  const safe = fileName
    .normalize("NFKD")
    .replace(/[^\w.\- ]+/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .slice(0, 120);
  return safe || "sourcebase-upload.bin";
}

function fileKind(fileName: string) {
  const lower = fileName.toLowerCase();
  if (lower.endsWith(".pdf")) return "pdf";
  if (lower.endsWith(".ppt") || lower.endsWith(".pptx")) return "pptx";
  if (lower.endsWith(".doc")) return "doc";
  if (lower.endsWith(".zip")) return "zip";
  return "docx";
}

function generatedTitle(kind: string) {
  const titles: Record<string, string> = {
    flashcard: "Flashcard Seti",
    question: "Soru Seti",
    summary: "Özet",
    algorithm: "Algoritma",
    comparison: "Karşılaştırma",
    podcast: "Podcast",
    table: "Tablo",
    mindMap: "Zihin Haritası",
  };
  return titles[kind] ?? "Üretilen İçerik";
}

function generatedCount(kind: string) {
  const counts: Record<string, number> = {
    flashcard: 125,
    question: 60,
    summary: 4,
    algorithm: 1,
    comparison: 1,
    podcast: 1,
    table: 1,
    mindMap: 1,
  };
  return counts[kind] ?? 1;
}

function encodePath(path: string) {
  return path.split("/").map(rfc3986Encode).join("/");
}

function canonicalQueryString(query: Record<string, string>) {
  return Object.entries(query)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${rfc3986Encode(key)}=${rfc3986Encode(value)}`)
    .join("&");
}

function rfc3986Encode(value: string) {
  return encodeURIComponent(value).replace(
    /[!'()*]/g,
    (char) => `%${char.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return toHex(new Uint8Array(digest));
}

async function rsaSha256(privateKeyPem: string, value: string) {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKeyPem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(value),
  );
  return toHex(new Uint8Array(signature));
}

function pemToArrayBuffer(pem: string) {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function toHex(bytes: Uint8Array) {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function formatDate(date: Date) {
  return date.toISOString().slice(0, 10).replaceAll("-", "");
}

function formatTime(date: Date) {
  return date.toISOString().slice(11, 19).replaceAll(":", "");
}

class SafeError extends Error {
  constructor(
    public code: string,
    message: string,
    public status = 400,
  ) {
    super(message);
  }
}
