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

const MAX_UPLOAD_BYTES = 100 * 1024 * 1024;
const MAX_TITLE_LENGTH = 120;
const MAX_SECTION_TITLE_LENGTH = 120;
const MAX_INITIAL_SECTIONS = 25;
const MAX_BATCH_FILE_IDS = 100;

const SUPPORTED_UPLOAD_TYPES: Record<
  string,
  { fileType: string; mimeTypes: string[] }
> = {
  pdf: { fileType: "pdf", mimeTypes: ["application/pdf"] },
  docx: {
    fileType: "docx",
    mimeTypes: [
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ],
  },
  pptx: {
    fileType: "pptx",
    mimeTypes: [
      "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ],
  },
};

const GENERATED_OUTPUT_TYPES = new Set([
  "flashcard",
  "question",
  "summary",
  "algorithm",
  "comparison",
  "clinical_scenario",
  "learning_plan",
  "podcast",
  "infographic",
  "mindMap",
  "table",
]);

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

    const rawBody = await request.json().catch(() => ({}));
    const body = isRecord(rawBody) ? rawBody : {};
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
  const storageRoots = await ensureStorageRoots(userId);
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
      roots: storageRoots,
    },
    ai: configStatus.vertex,
    courses,
    sections,
    files,
    generatedOutputs,
  };
}

async function ensureStorageRoots(userId: string) {
  const definitions = storageRootDefinitions(userId);
  const existing = await dbSelect(
    `storage_roots?owner_user_id=eq.${userId}&select=*`,
  );
  const existingKeys = new Set(
    existing.map((row) => String(row.root_key ?? "")).filter(Boolean),
  );
  const missing = definitions.filter((root) =>
    !existingKeys.has(root.root_key)
  );
  if (missing.length > 0) {
    await dbInsert(
      "storage_roots",
      missing.map((root) => ({
        owner_user_id: userId,
        root_key: root.root_key,
        title: root.title,
        gcs_prefix: root.gcs_prefix,
        status: "active",
        metadata: root.metadata,
      })),
    );
    await audit(userId, "ensure_storage_roots", "storage_root", null, {
      rootKeys: missing.map((root) => root.root_key),
    });
    await ensureGcsRootMarkers(definitions);
    return await dbSelect(
      `storage_roots?owner_user_id=eq.${userId}&select=*&order=created_at.asc`,
    );
  }
  await ensureGcsRootMarkers(definitions);
  return existing;
}

async function ensureGcsRootMarkers(
  definitions: ReturnType<typeof storageRootDefinitions>,
) {
  let gcs: GcsRuntime | null = null;
  try {
    gcs = getGcsConfig();
  } catch (_error) {
    return;
  }
  await Promise.all(
    definitions.map(async (root) => {
      const markerName = `${root.gcs_prefix}.keep`;
      const uploadUrl = await createGcsV4SignedPutUrl({
        bucket: gcs.bucket,
        objectName: markerName,
        contentType: "text/plain",
        serviceAccountJson: gcs.serviceAccountJson,
        expiresInSeconds: 300,
      });
      await fetch(uploadUrl, {
        method: "PUT",
        headers: { "content-type": "text/plain" },
        body: "",
      }).catch(() => undefined);
    }),
  );
}

type GcsRuntime = ReturnType<typeof getGcsConfig>;

function storageRootDefinitions(userId: string) {
  const base = `user/${userId}`;
  return [
    {
      root_key: "drive",
      title: "Drive",
      gcs_prefix: `${base}/drive/`,
      metadata: { purpose: "course_sources" },
    },
    {
      root_key: "uploads",
      title: "Yüklemeler",
      gcs_prefix: `${base}/drive/uploads/`,
      metadata: { purpose: "incoming_files" },
    },
    {
      root_key: "collections",
      title: "Koleksiyonlar",
      gcs_prefix: `${base}/collections/`,
      metadata: { purpose: "grouped_learning_assets" },
    },
    {
      root_key: "generated",
      title: "Üretilen İçerikler",
      gcs_prefix: `${base}/generated/`,
      metadata: { purpose: "ai_outputs" },
    },
  ];
}

async function createCourse(userId: string, payload: JsonMap) {
  const title = validateDisplayText(
    requireString(payload.title, "title"),
    "title",
    MAX_TITLE_LENGTH,
  );
  const description = optionalString(payload.description);
  const category = optionalString(payload.category);
  const iconName = optionalString(payload.iconName) ?? "book";
  const colorHex = optionalString(payload.colorHex);
  const initialSections = stringList(payload.initialSections)
    .slice(0, MAX_INITIAL_SECTIONS)
    .map((sectionTitle) =>
      validateDisplayText(
        sectionTitle,
        "initialSections",
        MAX_SECTION_TITLE_LENGTH,
      )
    );
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
  const title = validateDisplayText(
    requireString(payload.title, "title"),
    "title",
    MAX_SECTION_TITLE_LENGTH,
  );
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
  const title = validateDisplayText(
    requireString(payload.title, "title"),
    "title",
    MAX_TITLE_LENGTH,
  );
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
  const title = validateDisplayText(
    requireString(payload.title, "title"),
    "title",
    MAX_SECTION_TITLE_LENGTH,
  );
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

  const fileInfo = validateUploadFile(fileName, contentType, sizeBytes);
  await assertOwned(userId, "courses", courseId);
  await assertOwned(userId, "sections", sectionId);
  await assertSectionInCourse(userId, sectionId, courseId);

  await ensureStorageRoots(userId);
  const gcs = getGcsConfig();

  const safeName = sanitizeFileName(fileInfo.fileName);
  const sourceId = crypto.randomUUID();
  const objectName = `user/${userId}/drive/uploads/${sourceId}/${safeName}`;
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
  const uploadUrl = await createGcsV4SignedPutUrl({
    bucket: gcs.bucket,
    objectName,
    contentType: fileInfo.contentType,
    serviceAccountJson: gcs.serviceAccountJson,
    expiresInSeconds: 900,
  });

  return {
    uploadUrl,
    objectName,
    bucket: gcs.bucket,
    expiresAt: expiresAt.toISOString(),
    headers: { "Content-Type": fileInfo.contentType },
    metadata: {
      sourceId,
      courseId,
      sectionId,
      fileType: fileInfo.fileType,
      maxSizeBytes: MAX_UPLOAD_BYTES,
    },
  };
}

async function completeUpload(userId: string, payload: JsonMap) {
  const objectName = requireString(payload.objectName, "objectName");
  const courseId = requireString(payload.courseId, "courseId");
  const sectionId = requireString(payload.sectionId, "sectionId");
  const fileName = requireString(payload.fileName, "fileName");
  const contentType = requireString(payload.contentType, "contentType");
  const sizeBytes = Number(payload.sizeBytes ?? 0);
  const fileInfo = validateUploadFile(fileName, contentType, sizeBytes);
  assertUploadObjectName(
    userId,
    objectName,
    sanitizeFileName(fileInfo.fileName),
  );
  await assertOwned(userId, "courses", courseId);
  await assertOwned(userId, "sections", sectionId);
  await assertSectionInCourse(userId, sectionId, courseId);
  const gcs = getGcsConfig();

  const [existingRow] = await dbSelect(
    `drive_files?owner_user_id=eq.${userId}&gcs_object_name=eq.${
      encodeRestValue(objectName)
    }&select=*&limit=1`,
  );
  if (existingRow) {
    return {
      row: existingRow,
      objectName,
      status: String(existingRow.ai_status ?? existingRow.status ?? "uploaded"),
      nextAction: existingRow.ai_status === "ready"
        ? "generate"
        : "retry_file_processing",
    };
  }

  const objectMetadata = await getGcsObjectMetadata({
    bucket: gcs.bucket,
    objectName,
    serviceAccountJson: gcs.serviceAccountJson,
  });
  if (objectMetadata.contentLength !== sizeBytes) {
    throw new SafeError(
      "UPLOAD_SIZE_MISMATCH",
      "Yüklenen dosya boyutu doğrulanamadı.",
      400,
    );
  }
  if (
    objectMetadata.contentType &&
    !isAllowedMimeForFileType(fileInfo.fileType, objectMetadata.contentType)
  ) {
    throw new SafeError(
      "UPLOAD_TYPE_MISMATCH",
      "Yüklenen dosya türü doğrulanamadı.",
      400,
    );
  }

  const [row] = await dbInsert("drive_files", [{
    owner_user_id: userId,
    course_id: courseId,
    section_id: sectionId,
    title: fileInfo.fileName,
    file_type: fileInfo.fileType,
    original_filename: fileInfo.fileName,
    gcs_bucket: gcs.bucket,
    gcs_object_name: objectName,
    mime_type: fileInfo.contentType,
    size_bytes: objectMetadata.contentLength,
    page_count: null,
    status: "uploaded",
    ai_status: "processing",
    metadata: {
      upload: {
        contentType: objectMetadata.contentType || fileInfo.contentType,
        completedAt: new Date().toISOString(),
      },
    },
  }]);
  await audit(userId, "complete_upload", "drive_file", row.id, {
    courseId,
    sectionId,
    objectName,
  });

  try {
    await processFileExtraction(userId, { fileId: row.id });
  } catch (error) {
    const metadata = isRecord(row.metadata) ? row.metadata : {};
    await dbPatch(
      "drive_files",
      `id=eq.${row.id}&owner_user_id=eq.${userId}`,
      {
        ai_status: "failed",
        metadata: {
          ...metadata,
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
  const kind = normalizeGeneratedOutputKind(
    requireString(payload.kind, "kind"),
  );
  const jobId = optionalString(payload.jobId);
  await ensureStorageRoots(userId);
  await assertOwned(userId, "drive_files", fileId);
  const job = jobId
    ? await assertCompletedJobForFile(userId, jobId, fileId)
    : await findLatestCompletedJobForOutput(userId, fileId, kind);
  const jobMetadata = job && isRecord(job.metadata) ? job.metadata : {};
  const content = jobMetadata.content;
  const itemCount = boundedNumber(
    payload.itemCount,
    countGeneratedItems(content) ?? generatedCount(kind),
    1,
    500,
    "itemCount",
  );
  const [row] = await dbInsert("generated_outputs", [{
    owner_user_id: userId,
    source_file_id: fileId,
    output_type: kind,
    title: generatedTitle(kind),
    item_count: itemCount,
    status: "ready",
    metadata: {
      mode: job ? "ai_generation" : "manual_request",
      jobId: job?.id ?? jobId ?? null,
      content: content ?? null,
    },
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

async function assertCompletedJobForFile(
  userId: string,
  jobId: string,
  fileId: string,
) {
  const rows = await dbSelect(
    `generated_jobs?id=eq.${jobId}&owner_user_id=eq.${userId}&source_file_id=eq.${fileId}&select=*&limit=1`,
  );
  if (rows.length === 0) {
    throw new SafeError("JOB_NOT_FOUND", "İş bulunamadı veya yetkin yok.", 404);
  }
  if (rows[0].status !== "completed") {
    throw new SafeError(
      "JOB_NOT_COMPLETED",
      "Üretim işi tamamlanmadan içerik kaydı oluşturulamaz.",
      400,
    );
  }
  return rows[0];
}

async function findLatestCompletedJobForOutput(
  userId: string,
  fileId: string,
  kind: string,
) {
  const jobType = outputKindToJobType(kind);
  if (!jobType) return null;
  const rows = await dbSelect(
    `generated_jobs?owner_user_id=eq.${userId}&source_file_id=eq.${fileId}&job_type=eq.${jobType}&status=eq.completed&select=*&order=updated_at.desc&limit=1`,
  );
  return rows[0] ?? null;
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
    const rows = data.filter(isRecord);
    if (rows.length > 0) return rows;
  }
  throw new SafeError("DATABASE_ERROR", "SourceBase verisi işlenemedi.", 500);
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
    "X-Goog-SignedHeaders": "content-type;host",
  };
  const canonicalQuery = canonicalQueryString(query);
  const canonicalHeaders =
    `content-type:${input.contentType.toLowerCase()}\nhost:storage.googleapis.com\n`;
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

async function getGcsObjectMetadata(input: {
  bucket: string;
  objectName: string;
  serviceAccountJson: string;
}) {
  const url = await createGcsV4SignedHeadUrl({
    ...input,
    expiresInSeconds: 300,
  });
  const response = await fetch(url, { method: "HEAD" });
  if (response.status === 404) {
    throw new SafeError(
      "UPLOAD_NOT_FOUND",
      "Yüklenen dosya depolama alanında bulunamadı.",
      400,
    );
  }
  if (!response.ok) {
    throw new SafeError(
      "UPLOAD_VERIFY_FAILED",
      "Yüklenen dosya doğrulanamadı.",
      500,
    );
  }
  const contentLength = Number(response.headers.get("content-length") ?? 0);
  if (!Number.isFinite(contentLength) || contentLength <= 0) {
    throw new SafeError(
      "UPLOAD_EMPTY",
      "Yüklenen dosya boş görünüyor.",
      400,
    );
  }
  return {
    contentLength,
    contentType: response.headers.get("content-type")?.toLowerCase().trim() ??
      "",
  };
}

async function createGcsV4SignedHeadUrl(input: {
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
    "HEAD",
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
  if (list.length > MAX_BATCH_FILE_IDS) {
    throw new SafeError(
      "INVALID_PAYLOAD",
      `${name} çok fazla öğe içeriyor.`,
      400,
    );
  }
  return list;
}

function validateDisplayText(text: string, name: string, maxLength: number) {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (normalized.length < 2) {
    throw new SafeError("INVALID_PAYLOAD", `${name} çok kısa.`, 400);
  }
  if (normalized.length > maxLength) {
    throw new SafeError("INVALID_PAYLOAD", `${name} çok uzun.`, 400);
  }
  return normalized;
}

function boundedNumber(
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

function validateUploadFile(
  rawFileName: string,
  rawContentType: string,
  sizeBytes: number,
) {
  const fileName = rawFileName.replace(/\s+/g, " ").trim();
  const contentType = rawContentType.toLowerCase().split(";")[0].trim();
  if (
    !fileName || fileName.length > 180 || /[\\/]/.test(fileName) ||
    /[\x00-\x1F\x7F]/.test(fileName)
  ) {
    throw new SafeError("INVALID_FILE_NAME", "Dosya adı geçersiz.", 400);
  }
  if (
    !Number.isFinite(sizeBytes) || sizeBytes <= 0 ||
    sizeBytes > MAX_UPLOAD_BYTES
  ) {
    throw new SafeError(
      "INVALID_FILE_SIZE",
      "Dosya boyutu SourceBase yükleme sınırları dışında.",
      400,
    );
  }
  const extension = fileName.split(".").pop()?.toLowerCase() ?? "";
  const supported = SUPPORTED_UPLOAD_TYPES[extension];
  if (!supported) {
    throw new SafeError(
      "UNSUPPORTED_FILE_TYPE",
      "Bu dosya tipi desteklenmiyor.",
      400,
    );
  }
  if (!supported.mimeTypes.includes(contentType)) {
    throw new SafeError(
      "UNSUPPORTED_MIME_TYPE",
      "Dosya MIME tipi desteklenmiyor.",
      400,
    );
  }
  return { fileName, contentType, fileType: supported.fileType };
}

function isAllowedMimeForFileType(fileType: string, contentType: string) {
  const normalized = contentType.toLowerCase().split(";")[0].trim();
  const supported = Object.values(SUPPORTED_UPLOAD_TYPES).find((item) =>
    item.fileType === fileType
  );
  return Boolean(supported?.mimeTypes.includes(normalized));
}

function assertUploadObjectName(
  userId: string,
  objectName: string,
  expectedSafeName: string,
) {
  const prefix = `user/${userId}/drive/uploads/`;
  if (!objectName.startsWith(prefix)) {
    throw new SafeError("FORBIDDEN_OBJECT", "Dosya yolu yetkili değil.", 403);
  }
  const rest = objectName.slice(prefix.length);
  const parts = rest.split("/");
  const uuidLike =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (
    parts.length !== 2 || !uuidLike.test(parts[0]) ||
    parts[1] !== expectedSafeName
  ) {
    throw new SafeError("FORBIDDEN_OBJECT", "Dosya yolu doğrulanamadı.", 403);
  }
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

function normalizeGeneratedOutputKind(kind: string) {
  const normalized = kind.trim();
  const aliases: Record<string, string> = {
    quiz: "question",
    questions: "question",
    clinicalScenario: "clinical_scenario",
    clinical_scenario: "clinical_scenario",
    learningPlan: "learning_plan",
    learning_plan: "learning_plan",
    infographic: "infographic",
    mind_map: "mindMap",
    mindmap: "mindMap",
    mindMap: "mindMap",
  };
  const outputType = aliases[normalized] ?? normalized;
  if (!GENERATED_OUTPUT_TYPES.has(outputType)) {
    throw new SafeError(
      "UNSUPPORTED_OUTPUT_TYPE",
      "Bu içerik türü desteklenmiyor.",
      400,
    );
  }
  return outputType;
}

function outputKindToJobType(kind: string) {
  const mapping: Record<string, string> = {
    flashcard: "flashcard",
    question: "quiz",
    summary: "summary",
    algorithm: "algorithm",
    comparison: "comparison",
    clinical_scenario: "clinical_scenario",
    learning_plan: "learning_plan",
    podcast: "podcast",
    infographic: "infographic",
    mindMap: "mind_map",
  };
  return mapping[kind];
}

function countGeneratedItems(content: unknown): number | undefined {
  if (Array.isArray(content)) return content.length || undefined;
  if (!isRecord(content)) return undefined;
  const candidateKeys = [
    "bulletPoints",
    "steps",
    "rows",
    "segments",
    "questions",
    "teachingPoints",
    "objectives",
    "sessions",
    "sections",
    "branches",
  ];
  for (const key of candidateKeys) {
    const value = content[key];
    if (Array.isArray(value) && value.length > 0) return value.length;
  }
  return 1;
}

function generatedTitle(kind: string) {
  const titles: Record<string, string> = {
    flashcard: "Flashcard Seti",
    question: "Soru Seti",
    summary: "Özet",
    algorithm: "Algoritma",
    comparison: "Karşılaştırma",
    clinical_scenario: "Klinik Senaryo",
    learning_plan: "Öğrenme Planı",
    podcast: "Podcast",
    infographic: "İnfografik",
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
    clinical_scenario: 1,
    learning_plan: 1,
    podcast: 1,
    infographic: 1,
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

function encodeRestValue(value: string) {
  return encodeURIComponent(value);
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
