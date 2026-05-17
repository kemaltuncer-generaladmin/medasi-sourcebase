import { isRecord, SafeError } from "./types.ts";
import {
  getGcsConfig,
  parseGoogleServiceAccount,
  runtimeConfigStatus,
} from "./config.ts";
import {
  cancelJob,
  centralAiChat,
  createGenerationJob,
  getGeneratedContent,
  getJobStatus,
  listUserJobs,
  processFileExtraction,
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
      case "runtime_config":
        return success(runtimeConfigStatus());
      case "drive_bootstrap":
        return success(await driveBootstrap(user.id));
      case "create_course":
        return success(await createCourse(user.id, payload));
      case "create_section":
        return success(await createSection(user.id, payload));
      case "rename_course":
        return success(await renameCourse(user.id, payload));
      case "rename_section":
        return success(await renameSection(user.id, payload));
      case "delete_course":
        return success(await deleteCourse(user.id, payload));
      case "delete_section":
        return success(await deleteSection(user.id, payload));
      case "create_upload_session":
        return success(await createUploadSession(user.id, payload));
      case "complete_upload":
        return success(await completeUpload(user.id, payload));
      case "create_generated_output":
        return success(await createGeneratedOutput(user.id, payload));
      case "rename_file":
        return success(await renameFile(user.id, payload));
      case "move_files":
        return success(await moveFiles(user.id, payload));
      case "delete_files":
        return success(await deleteFiles(user.id, payload));
      case "retry_file_processing":
        return success(await retryFileProcessing(user.id, payload));
      case "add_to_collection":
        return success(await addToCollection(user.id, payload));

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
      case "central_ai_chat":
        return success(await centralAiChat(user.id, payload));

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
  const configStatus = runtimeConfigStatus();
  return {
    storage: {
      ...configStatus.gcs,
    },
    ai: configStatus.vertex,
    courses,
    sections,
    files,
    generatedOutputs,
  };
}

async function createCourse(userId: string, payload: JsonMap) {
  const title = requireString(payload.title, "title");
  const description = optionalString(payload.description);
  const category = optionalString(payload.category);
  const iconName = optionalString(payload.iconName) ?? "book";
  const colorHex = optionalString(payload.colorHex);
  const initialSections = stringList(payload.initialSections);
  const [row] = await dbInsert("courses", [{
    owner_user_id: userId,
    title,
    icon_name: iconName,
    subject: category ?? title,
    status: "active",
    metadata: {
      description: description ??
        `${title} dersine ait içerikler için yeni alan hazır.`,
      category,
      colorHex,
    },
  }]);
  if (initialSections.length > 0) {
    await dbInsert(
      "sections",
      initialSections.map((sectionTitle, index) => ({
        owner_user_id: userId,
        course_id: row.id,
        title: sectionTitle,
        status: "active",
        sort_order: index,
      })),
    );
  }
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

async function renameCourse(userId: string, payload: JsonMap) {
  const courseId = requireString(payload.courseId, "courseId");
  const title = requireString(payload.title, "title");
  await assertOwned(userId, "courses", courseId);
  const [row] = await dbPatchReturning(
    "courses",
    `id=eq.${courseId}&owner_user_id=eq.${userId}`,
    { title, subject: title, updated_at: new Date().toISOString() },
  );
  await audit(userId, "rename_course", "course", courseId, { title });
  return { row };
}

async function renameSection(userId: string, payload: JsonMap) {
  const sectionId = requireString(payload.sectionId, "sectionId");
  const title = requireString(payload.title, "title");
  await assertOwned(userId, "sections", sectionId);
  const [row] = await dbPatchReturning(
    "sections",
    `id=eq.${sectionId}&owner_user_id=eq.${userId}`,
    { title, updated_at: new Date().toISOString() },
  );
  await audit(userId, "rename_section", "section", sectionId, { title });
  return { row };
}

async function deleteCourse(userId: string, payload: JsonMap) {
  const courseId = requireString(payload.courseId, "courseId");
  await assertOwned(userId, "courses", courseId);
  const fileRows = await dbSelect(
    `drive_files?course_id=eq.${courseId}&owner_user_id=eq.${userId}&select=id`,
  );
  const fileIds = fileRows.map((row) => String(row.id)).filter(Boolean);
  if (fileIds.length > 0) {
    await deleteFiles(userId, { fileIds });
  }
  await dbDelete("courses", `id=eq.${courseId}&owner_user_id=eq.${userId}`);
  await audit(userId, "delete_course", "course", courseId, { fileIds });
  return { deletedId: courseId, deletedFileIds: fileIds };
}

async function deleteSection(userId: string, payload: JsonMap) {
  const sectionId = requireString(payload.sectionId, "sectionId");
  await assertOwned(userId, "sections", sectionId);
  const fileRows = await dbSelect(
    `drive_files?section_id=eq.${sectionId}&owner_user_id=eq.${userId}&select=id`,
  );
  const fileIds = fileRows.map((row) => String(row.id)).filter(Boolean);
  if (fileIds.length > 0) {
    await deleteFiles(userId, { fileIds });
  }
  await dbDelete("sections", `id=eq.${sectionId}&owner_user_id=eq.${userId}`);
  await audit(userId, "delete_section", "section", sectionId, { fileIds });
  return { deletedId: sectionId, deletedFileIds: fileIds };
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

  const gcs = getGcsConfig();

  const safeName = sanitizeFileName(fileName);
  const sourceId = crypto.randomUUID();
  const objectName = `user/${userId}/sources/${sourceId}/${safeName}`;
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
  const uploadUrl = await createGcsV4SignedPutUrl({
    bucket: gcs.bucket,
    objectName,
    contentType,
    serviceAccountJson: gcs.serviceAccountJson,
    expiresInSeconds: 900,
  });

  return {
    uploadUrl,
    objectName,
    bucket: gcs.bucket,
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
  await assertSectionInCourse(userId, sectionId, courseId);
  const gcs = getGcsConfig();
  const [row] = await dbInsert("drive_files", [{
    owner_user_id: userId,
    course_id: courseId,
    section_id: sectionId,
    title: fileName,
    file_type: fileKind(fileName),
    original_filename: fileName,
    gcs_bucket: gcs.bucket,
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

  try {
    await processFileExtraction(userId, { fileId: row.id });
  } catch (error) {
    await dbPatch(
      "drive_files",
      `id=eq.${row.id}&owner_user_id=eq.${userId}`,
      {
        ai_status: "failed",
        metadata: {
          extractionError: error instanceof SafeError
            ? error.message
            : "Dosya metni çıkarılamadı.",
          extractionFailedAt: new Date().toISOString(),
        },
      },
    );
    const [failedRow] = await dbSelect(
      `drive_files?id=eq.${row.id}&owner_user_id=eq.${userId}&select=*&limit=1`,
    );
    return {
      row: failedRow ?? row,
      objectName,
      status: "processing_failed",
      nextAction: "retry_file_processing",
    };
  }

  const [readyRow] = await dbSelect(
    `drive_files?id=eq.${row.id}&owner_user_id=eq.${userId}&select=*&limit=1`,
  );

  return {
    row: readyRow ?? row,
    objectName,
    status: "ready",
    nextAction: "generate",
  };
}

async function renameFile(userId: string, payload: JsonMap) {
  const fileId = requireString(payload.fileId, "fileId");
  const title = requireString(payload.title, "title");
  await assertOwned(userId, "drive_files", fileId);
  const [row] = await dbPatchReturning(
    "drive_files",
    `id=eq.${fileId}&owner_user_id=eq.${userId}`,
    { title, updated_at: new Date().toISOString() },
  );
  await audit(userId, "rename_file", "drive_file", fileId, { title });
  return { row };
}

async function moveFiles(userId: string, payload: JsonMap) {
  const fileIds = requireStringList(payload.fileIds, "fileIds");
  const courseId = requireString(payload.courseId, "courseId");
  const sectionId = requireString(payload.sectionId, "sectionId");
  await assertOwned(userId, "courses", courseId);
  await assertOwned(userId, "sections", sectionId);
  await assertSectionInCourse(userId, sectionId, courseId);
  await assertFilesOwned(userId, fileIds);
  const rows = await dbPatchReturning(
    "drive_files",
    `id=in.(${fileIds.join(",")})&owner_user_id=eq.${userId}`,
    {
      course_id: courseId,
      section_id: sectionId,
      updated_at: new Date().toISOString(),
    },
  );
  await audit(userId, "move_files", "drive_file", null, {
    fileIds,
    courseId,
    sectionId,
  });
  return { rows };
}

async function deleteFiles(userId: string, payload: JsonMap) {
  const fileIds = requireStringList(payload.fileIds, "fileIds");
  await assertFilesOwned(userId, fileIds);
  const rows = await dbSelect(
    `drive_files?id=in.(${
      fileIds.join(",")
    })&owner_user_id=eq.${userId}&select=id,gcs_bucket,gcs_object_name`,
  );
  const gcs = getGcsConfig();
  for (const row of rows) {
    const objectName = String(row.gcs_object_name ?? "");
    const bucket = String(row.gcs_bucket ?? "") || gcs.bucket;
    if (objectName) {
      await deleteGcsObject({
        bucket,
        objectName,
        serviceAccountJson: gcs.serviceAccountJson,
      });
    }
  }
  await dbDelete(
    "drive_files",
    `id=in.(${fileIds.join(",")})&owner_user_id=eq.${userId}`,
  );
  await audit(userId, "delete_files", "drive_file", null, { fileIds });
  return { deletedIds: fileIds };
}

async function retryFileProcessing(userId: string, payload: JsonMap) {
  const fileId = requireString(payload.fileId, "fileId");
  await assertOwned(userId, "drive_files", fileId);
  await dbPatch(
    "drive_files",
    `id=eq.${fileId}&owner_user_id=eq.${userId}`,
    {
      ai_status: "processing",
      updated_at: new Date().toISOString(),
    },
  );
  try {
    await processFileExtraction(userId, { fileId });
  } catch (error) {
    await dbPatch(
      "drive_files",
      `id=eq.${fileId}&owner_user_id=eq.${userId}`,
      {
        ai_status: "failed",
        metadata: {
          extractionError: error instanceof SafeError
            ? error.message
            : "Dosya metni çıkarılamadı.",
          extractionFailedAt: new Date().toISOString(),
        },
      },
    );
    throw error;
  }
  const [row] = await dbSelect(
    `drive_files?id=eq.${fileId}&owner_user_id=eq.${userId}&select=*&limit=1`,
  );
  await audit(userId, "retry_file_processing", "drive_file", fileId, {});
  return { row };
}

async function addToCollection(userId: string, payload: JsonMap) {
  const fileIds = requireStringList(payload.fileIds, "fileIds");
  await assertFilesOwned(userId, fileIds);
  const existingRows = await dbSelect(
    `drive_files?id=in.(${
      fileIds.join(",")
    })&owner_user_id=eq.${userId}&select=id,metadata`,
  );
  const pinnedAt = new Date().toISOString();
  for (const row of existingRows) {
    const metadata = isRecord(row.metadata) ? row.metadata : {};
    await dbPatch(
      "drive_files",
      `id=eq.${row.id}&owner_user_id=eq.${userId}`,
      {
        metadata: { ...metadata, collectionPinnedAt: pinnedAt },
        updated_at: pinnedAt,
      },
    );
  }
  await audit(userId, "add_to_collection", "drive_file", null, { fileIds });
  return { fileIds, collectionPinnedAt: pinnedAt };
}

async function createGeneratedOutput(userId: string, payload: JsonMap) {
  const fileId = requireString(payload.fileId, "fileId");
  const kind = requireString(payload.kind, "kind");
  const itemCount = Number(payload.itemCount ?? generatedCount(kind));
  await assertOwned(userId, "drive_files", fileId);
  const [row] = await dbInsert("generated_outputs", [{
    owner_user_id: userId,
    source_file_id: fileId,
    output_type: kind,
    title: generatedTitle(kind),
    item_count: Number.isFinite(itemCount) ? itemCount : generatedCount(kind),
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

async function assertFilesOwned(userId: string, fileIds: string[]) {
  const rows = await dbSelect(
    `drive_files?id=in.(${
      fileIds.join(",")
    })&owner_user_id=eq.${userId}&select=id`,
  );
  if (rows.length !== fileIds.length) {
    throw new SafeError("NOT_FOUND", "Dosya bulunamadı veya yetkin yok.", 404);
  }
}

async function assertSectionInCourse(
  userId: string,
  sectionId: string,
  courseId: string,
) {
  const rows = await dbSelect(
    `sections?id=eq.${sectionId}&course_id=eq.${courseId}&owner_user_id=eq.${userId}&select=id&limit=1`,
  );
  if (rows.length === 0) {
    throw new SafeError(
      "SECTION_COURSE_MISMATCH",
      "Bölüm bu derse ait değil.",
      400,
    );
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

async function dbPatch(
  table: string,
  query: string,
  body: JsonMap,
): Promise<void> {
  await supabaseRest(`${table}?${query}`, {
    method: "PATCH",
    body: JSON.stringify(body),
  });
}

async function dbPatchReturning(
  table: string,
  query: string,
  body: JsonMap,
): Promise<JsonMap[]> {
  const response = await supabaseRest(`${table}?${query}`, {
    method: "PATCH",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify(body),
  });
  const data = await response.json();
  return Array.isArray(data) ? data.filter(isRecord) : [];
}

async function dbDelete(table: string, query: string): Promise<void> {
  await supabaseRest(`${table}?${query}`, { method: "DELETE" });
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
  const serviceAccount = parseGoogleServiceAccount(
    input.serviceAccountJson,
    "GCS_SERVICE_ACCOUNT_INVALID",
  );

  const now = new Date();
  const date = formatDate(now);
  const timestamp = `${date}T${formatTime(now)}Z`;
  const scope = `${date}/auto/storage/goog4_request`;
  const credential = `${serviceAccount.clientEmail}/${scope}`;
  const canonicalUri = `/${encodePath(input.bucket)}/${
    encodePath(input.objectName)
  }`;
  const query: Record<string, string> = {
    "X-Goog-Algorithm": "GOOG4-RSA-SHA256",
    "X-Goog-Credential": credential,
    "X-Goog-Date": timestamp,
    "X-Goog-Expires": String(input.expiresInSeconds),
    "X-Goog-SignedHeaders": "host",
  };
  const canonicalQuery = canonicalQueryString(query);
  const canonicalHeaders = "host:storage.googleapis.com\n";
  const canonicalRequest = [
    "PUT",
    canonicalUri,
    canonicalQuery,
    canonicalHeaders,
    "host",
    "UNSIGNED-PAYLOAD",
  ].join("\n");
  const stringToSign = [
    "GOOG4-RSA-SHA256",
    timestamp,
    scope,
    await sha256Hex(canonicalRequest),
  ].join("\n");
  const signature = await rsaSha256(serviceAccount.privateKey, stringToSign);
  return `https://storage.googleapis.com${canonicalUri}?${canonicalQuery}&X-Goog-Signature=${signature}`;
}

async function deleteGcsObject(input: {
  bucket: string;
  objectName: string;
  serviceAccountJson: string;
}) {
  const url = await createGcsV4SignedDeleteUrl({
    ...input,
    expiresInSeconds: 300,
  });
  const response = await fetch(url, { method: "DELETE" });
  if (!response.ok && response.status !== 404) {
    throw new SafeError(
      "GCS_DELETE_FAILED",
      "Dosya depolama alanından silinemedi.",
      500,
    );
  }
}

async function createGcsV4SignedDeleteUrl(input: {
  bucket: string;
  objectName: string;
  serviceAccountJson: string;
  expiresInSeconds: number;
}) {
  const serviceAccount = parseGoogleServiceAccount(
    input.serviceAccountJson,
    "GCS_SERVICE_ACCOUNT_INVALID",
  );
  const now = new Date();
  const date = formatDate(now);
  const timestamp = `${date}T${formatTime(now)}Z`;
  const scope = `${date}/auto/storage/goog4_request`;
  const credential = `${serviceAccount.clientEmail}/${scope}`;
  const canonicalUri = `/${encodePath(input.bucket)}/${
    encodePath(input.objectName)
  }`;
  const query: Record<string, string> = {
    "X-Goog-Algorithm": "GOOG4-RSA-SHA256",
    "X-Goog-Credential": credential,
    "X-Goog-Date": timestamp,
    "X-Goog-Expires": String(input.expiresInSeconds),
    "X-Goog-SignedHeaders": "host",
  };
  const canonicalQuery = canonicalQueryString(query);
  const canonicalHeaders = "host:storage.googleapis.com\n";
  const canonicalRequest = [
    "DELETE",
    canonicalUri,
    canonicalQuery,
    canonicalHeaders,
    "host",
    "UNSIGNED-PAYLOAD",
  ].join("\n");
  const stringToSign = [
    "GOOG4-RSA-SHA256",
    timestamp,
    scope,
    await sha256Hex(canonicalRequest),
  ].join("\n");
  const signature = await rsaSha256(serviceAccount.privateKey, stringToSign);
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

function requireString(value: unknown, name: string) {
  const text = value?.toString().trim() ?? "";
  if (!text) {
    throw new SafeError("INVALID_PAYLOAD", `${name} alanı zorunlu.`, 400);
  }
  return text;
}

function optionalString(value: unknown) {
  const text = value?.toString().trim() ?? "";
  return text.length === 0 ? undefined : text;
}

function stringList(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => item?.toString().trim() ?? "")
    .filter((item) => item.length > 0);
}

function requireStringList(value: unknown, name: string) {
  const list = stringList(value);
  if (list.length === 0) {
    throw new SafeError("INVALID_PAYLOAD", `${name} alanı zorunlu.`, 400);
  }
  return list;
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
