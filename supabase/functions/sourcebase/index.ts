import { isRecord, SafeError } from "./types.ts";
import {
  getAllowedOrigin,
  getObjectStorageConfig,
  getSupabaseAnonKey,
  getSupabaseServiceRoleKey,
  getSupabaseUrl,
  runtimeConfigStatus,
} from "./config.ts";
import {
  cancelJob,
  centralAiChat,
  createGenerationJob,
  estimateGenerationCost,
  getGeneratedContent,
  getJobStatus,
  listUserJobs,
  processFileExtraction,
  processGenerationJob,
  retryJob,
} from "./actions/ai-generation.ts";
import {
  canonicalContentTypeFor,
  isSupportedSourceFileType,
  normalizeSourceFileType,
} from "./services/file-types.ts";
import {
  createSignedPutUrl,
  createSignedReadUrl,
  deleteObject,
  getObjectMetadata,
  ObjectMetadata,
} from "./services/object-storage.ts";
import {
  appleRootCertificates,
  verifyAndDecodeAppleJws,
} from "../_shared/appstore_jws.ts";

type JsonMap = Record<string, unknown>;
type StorageObjectMetadata = ObjectMetadata;
type CompatibleQuestion = {
  id: string;
  subject: string;
  topic: string;
  difficulty: string;
  text: string;
  options: string[];
  correctIndex: number;
  explanation: string;
  optionRationales: string[];
  tags: string[];
};

const MAX_UPLOAD_BYTES = 100 * 1024 * 1024;
const MAX_AVATAR_UPLOAD_BYTES = 5 * 1024 * 1024;
const MAX_TITLE_LENGTH = 120;
const MAX_SECTION_TITLE_LENGTH = 120;
const MAX_INITIAL_SECTIONS = 25;
const MAX_BATCH_FILE_IDS = 100;

const GENERATED_OUTPUT_TYPES = new Set([
  "flashcard",
  "question",
  "summary",
  "algorithm",
  "comparison",
  "clinical_scenario",
  "learning_plan",
  "podcast",
  "podcast_summary",
  "exam_morning_summary",
  "infographic",
  "mind_map",
  "mindMap",
  "table",
]);

const DEFAULT_ALLOWED_ORIGIN = "https://sourcebase.medasi.com.tr";

const corsHeaders = {
  "Access-Control-Allow-Origin": allowedCorsOrigin(),
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
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
      case "move_generated_output":
        return success(await moveGeneratedOutput(user.id, payload));
      case "delete_files":
        return success(await deleteFiles(user.id, payload));
      case "retry_file_processing":
        return success(await retryFileProcessing(user.id, payload));
      case "add_to_collection":
        return success(await addToCollection(user.id, payload));
      case "purchase_medasicoin":
        return success(await purchaseMedasiCoin(user.id, payload));
      case "redeem_appstore_purchase":
        return success(await redeemAppStorePurchase(user, payload));
      case "sourcebase_question_session":
        return success(await sourcebaseQuestionSession(user.id, payload));
      case "submit_sourcebase_question_answer":
        return success(await submitSourcebaseQuestionAnswer(user.id, payload));
      case "get_generated_asset_url":
        return success(await getGeneratedAssetUrl(user.id, payload));
      case "create_profile_avatar_upload_session":
        return success(
          await createProfileAvatarUploadSession(user.id, payload),
        );
      case "complete_profile_avatar_upload":
        return success(await completeProfileAvatarUpload(user.id, payload));
      case "submit_support_form":
        return success(await submitSupportForm(user.id, payload));
      case "request_account_deletion":
        return success(await requestAccountDeletion(user, payload));

      // AI Generation actions
      case "process_file_extraction":
        return success(await processFileExtraction(user.id, payload));
      case "create_generation_job":
        return success(await createGenerationJob(user.id, payload));
      case "process_generation_job":
        return success(await processGenerationJob(user.id, payload));
      case "estimate_generation_cost":
        return success(await estimateGenerationCost(user.id, payload));
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
  const supabaseUrl = getSupabaseUrl();
  const anonKey = getSupabaseAnonKey();
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
      ...configStatus.storage,
      roots: storageRoots,
    },
    ai: configStatus.ai,
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
        storage_prefix: root.storage_prefix,
        status: "active",
        metadata: root.metadata,
      })),
    );
    await audit(userId, "ensure_storage_roots", "storage_root", null, {
      rootKeys: missing.map((root) => root.root_key),
    });
    return await dbSelect(
      `storage_roots?owner_user_id=eq.${userId}&select=*&order=created_at.asc`,
    );
  }
  return existing;
}

function storageRootDefinitions(userId: string) {
  const base = `sourcebase/users/${userId}`;
  return [
    {
      root_key: "drive",
      title: "Drive",
      storage_prefix: `${base}/drive/`,
      metadata: { purpose: "course_sources" },
    },
    {
      root_key: "uploads",
      title: "Yüklemeler",
      storage_prefix: `${base}/uploads/`,
      metadata: { purpose: "incoming_files" },
    },
    {
      root_key: "collections",
      title: "Koleksiyonlar",
      storage_prefix: `${base}/collections/`,
      metadata: { purpose: "grouped_learning_assets" },
    },
    {
      root_key: "generated",
      title: "Üretilen İçerikler",
      storage_prefix: `${base}/generated/`,
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
  const courseId = requireUuid(payload.courseId, "courseId");
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
  const courseId = requireUuid(payload.courseId, "courseId");
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
  const sectionId = requireUuid(payload.sectionId, "sectionId");
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
  const courseId = requireUuid(payload.courseId, "courseId");
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
  const sectionId = requireUuid(payload.sectionId, "sectionId");
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
  const courseId = requireUuid(payload.courseId, "courseId");
  const sectionId = requireUuid(payload.sectionId, "sectionId");
  const sizeBytes = Number(payload.sizeBytes ?? 0);

  const fileInfo = validateUploadFile(fileName, contentType, sizeBytes);
  await assertOwned(userId, "courses", courseId);
  await assertOwned(userId, "sections", sectionId);
  await assertSectionInCourse(userId, sectionId, courseId);

  await ensureStorageRoots(userId);
  const storage = getObjectStorageConfig();

  const safeName = sanitizeFileName(fileInfo.fileName);
  const sourceId = crypto.randomUUID();
  const now = new Date();
  const year = String(now.getUTCFullYear());
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  const objectName =
    `sourcebase/users/${userId}/uploads/${year}/${month}/${sourceId}-${safeName}`;
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
  const uploadUrl = await createSignedPutUrl({
    storage: storage,
    objectName,
    expiresInSeconds: 900,
  });

  return {
    uploadUrl,
    objectName,
    bucket: storage.bucket,
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
  const courseId = requireUuid(payload.courseId, "courseId");
  const sectionId = requireUuid(payload.sectionId, "sectionId");
  const fileName = requireString(payload.fileName, "fileName");
  const contentType = requireString(payload.contentType, "contentType");
  const sizeBytes = Number(payload.sizeBytes ?? 0);

  const extractedText = typeof payload.extractedText === "string" ? payload.extractedText : null;
  const pageCount = typeof payload.pageCount === "number" ? payload.pageCount : null;
  const extractionMetadata = isRecord(payload.extractionMetadata) ? payload.extractionMetadata : null;

  const fileInfo = validateUploadFile(fileName, contentType, sizeBytes);
  assertUploadObjectName(
    userId,
    objectName,
    sanitizeFileName(fileInfo.fileName),
  );
  await assertOwned(userId, "courses", courseId);
  await assertOwned(userId, "sections", sectionId);
  await assertSectionInCourse(userId, sectionId, courseId);
  const storage = getObjectStorageConfig();

  const objectMetadata = await getObjectMetadata({
    storage: storage,
    bucket: storage.bucket,
    objectName,
  });
  assertCompletedUploadMatches({
    expectedObjectName: objectName,
    expectedContentType: fileInfo.contentType,
    expectedFileType: fileInfo.fileType,
    expectedSizeBytes: sizeBytes,
    metadata: objectMetadata,
  });

  const [existingRow] = await dbSelect(
    `drive_files?owner_user_id=eq.${userId}&storage_object_name=eq.${
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

  const hasClientExtraction = extractedText && extractedText.length > 0;

  const [row] = await dbInsert("drive_files", [{
    owner_user_id: userId,
    course_id: courseId,
    section_id: sectionId,
    title: fileInfo.fileName,
    file_type: fileInfo.fileType,
    original_filename: fileInfo.fileName,
    storage_bucket: storage.bucket,
    storage_object_name: objectName,
    mime_type: fileInfo.contentType,
    size_bytes: objectMetadata.contentLength,
    page_count: pageCount,
    status: hasClientExtraction ? "ready" : "uploaded",
    ai_status: hasClientExtraction ? "ready" : "processing",
    metadata: {
      upload: {
        contentType: objectMetadata.contentType || fileInfo.contentType,
        completedAt: new Date().toISOString(),
      },
      ...(hasClientExtraction ? {
        extractedText,
        charCount: extractionMetadata?.charCount ?? extractedText!.length,
        wordCount: extractionMetadata?.wordCount ?? extractedText!.split(/\s+/).length,
        extractedAt: extractionMetadata?.extractedAt ?? new Date().toISOString(),
        extractionSource: "client",
      } : {}),
    },
  }]);
  await audit(userId, "complete_upload", "drive_file", row.id, {
    courseId,
    sectionId,
    objectName,
    clientExtraction: hasClientExtraction,
  });

  if (!hasClientExtraction) {
    try {
      await processFileExtraction(userId, { fileId: row.id });
    } catch (error) {
      const metadata = isRecord(row.metadata) ? row.metadata : {};
      const errorCode = error instanceof SafeError
        ? error.code
        : "FILE_PARSE_FAILED";
      const errorMessage = error instanceof SafeError
        ? error.message
        : "Dosya metni çıkarılamadı.";
      await dbPatch(
        "drive_files",
        `id=eq.${row.id}&owner_user_id=eq.${userId}`,
        {
          ai_status: "failed",
          metadata: {
            ...metadata,
            extractionErrorCode: errorCode,
            extractionError: errorMessage,
            extractionFailedAt: new Date().toISOString(),
          },
        },
      );
      throw error;
    }
  }

  const [readyRow] = await dbSelect(
    `drive_files?id=eq.${row.id}&owner_user_id=eq.${userId}&select=*&limit=1`,
  );

  return {
    row: readyRow ?? row,
    objectName,
    status: hasClientExtraction ? "ready" : "ready",
    nextAction: "generate",
  };
}

async function renameFile(userId: string, payload: JsonMap) {
  const fileId = requireUuid(payload.fileId, "fileId");
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
  const fileIds = requireUuidList(payload.fileIds, "fileIds");
  const courseId = requireUuid(payload.courseId, "courseId");
  const sectionId = requireUuid(payload.sectionId, "sectionId");
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
  const fileIds = requireUuidList(payload.fileIds, "fileIds");
  await assertFilesOwned(userId, fileIds);
  const rows = await dbSelect(
    `drive_files?id=in.(${
      fileIds.join(",")
    })&owner_user_id=eq.${userId}&select=id,storage_bucket,storage_object_name`,
  );
  const storage = safeGetStorageConfigForDelete();
  for (const row of rows) {
    const objectName = String(row.storage_object_name ?? "");
    const bucket = String(row.storage_bucket ?? "") || storage?.bucket || "";
    if (storage && objectName && bucket) {
      await deleteObject({
        storage: storage,
        bucket,
        objectName,
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
  const fileId = requireUuid(payload.fileId, "fileId");
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
    const errorCode = error instanceof SafeError
      ? error.code
      : "FILE_PARSE_FAILED";
    const errorMessage = error instanceof SafeError
      ? error.message
      : "Dosya metni çıkarılamadı.";
    await dbPatch(
      "drive_files",
      `id=eq.${fileId}&owner_user_id=eq.${userId}`,
      {
        ai_status: "failed",
        metadata: {
          extractionErrorCode: errorCode,
          extractionError: errorMessage,
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
  const fileIds = requireUuidList(payload.fileIds, "fileIds");
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

async function purchaseMedasiCoin(_userId: string, payload: JsonMap) {
  requireString(payload.product_code, "product_code");
  throw new SafeError(
    "PAYMENT_UNAVAILABLE",
    "Ödeme servisi şu anda kullanılamıyor. Kartından ücret alınmadı.",
    503,
  );
}

async function createGeneratedOutput(userId: string, payload: JsonMap) {
  const fileId = requireUuid(payload.fileId, "fileId");
  const kind = normalizeGeneratedOutputKind(
    requireString(payload.kind, "kind"),
  );
  const jobId = optionalUuid(payload.jobId, "jobId");
  await ensureStorageRoots(userId);
  await assertOwned(userId, "drive_files", fileId);
  const job = jobId
    ? await assertCompletedJobForFile(userId, jobId, fileId)
    : await findLatestCompletedJobForOutput(userId, fileId, kind);
  if (!job) {
    throw new SafeError(
      "COMPLETED_JOB_REQUIRED",
      "Kaydedilecek tamamlanmış AI üretimi bulunamadı.",
      400,
    );
  }
  const jobMetadata = job && isRecord(job.metadata) ? job.metadata : {};
  const content = jobMetadata.content;
  if (isEmptyGeneratedContent(content)) {
    throw new SafeError(
      "GENERATED_CONTENT_EMPTY",
      "AI üretim sonucu boş olduğu için kaydedilemedi.",
      400,
    );
  }
  const completedJobId = job.id?.toString() ?? "";
  if (!completedJobId) {
    throw new SafeError(
      "COMPLETED_JOB_REQUIRED",
      "Kaydedilecek tamamlanmış AI üretimi bulunamadı.",
      400,
    );
  }
  const itemCount = boundedNumber(
    payload.itemCount,
    countGeneratedItems(content) ?? generatedCount(kind),
    1,
    500,
    "itemCount",
  );
  const existing = await findGeneratedOutputByJob(
    userId,
    fileId,
    kind,
    completedJobId,
  );
  if (existing) {
    return { row: existing, alreadyExists: true };
  }
  const [row] = await dbInsert("generated_outputs", [{
    owner_user_id: userId,
    source_file_id: fileId,
    output_type: kind,
    title: generatedTitle(kind),
    item_count: itemCount,
    status: "ready",
    metadata: {
      mode: "ai_generation",
      jobId: completedJobId,
      content,
    },
  }]);
  await audit(userId, "create_generated_output", "generated_output", row.id, {
    fileId,
    kind,
  });
  return { row };
}

async function sourcebaseQuestionSession(userId: string, payload: JsonMap) {
  const outputId = requireUuid(payload.outputId, "outputId");
  const output = await loadGeneratedOutput(userId, outputId);
  const questions = extractQlinikCompatibleQuestions(output);
  if (questions.length === 0) {
    throw new SafeError(
      "QUESTION_SET_NOT_COMPATIBLE",
      "Bu materyalden çözülebilir 5 şıklı soru seti bulunamadı.",
      400,
    );
  }

  await persistCandidateQuestions(userId, output, questions);
  await audit(
    userId,
    "sourcebase_question_session",
    "generated_output",
    outputId,
    {
      questionCount: questions.length,
    },
  );

  return {
    outputId,
    questions: questions.map(publicQuestionPrompt),
  };
}

async function submitSourcebaseQuestionAnswer(
  userId: string,
  payload: JsonMap,
) {
  const outputId = requireUuid(payload.outputId, "outputId");
  const questionId = requireString(payload.questionId, "questionId");
  const selectedIndex = boundedNumber(
    payload.selectedIndex,
    -1,
    0,
    4,
    "selectedIndex",
  );
  const elapsedSeconds = optionalInteger(
    payload.elapsedSeconds,
    0,
    24 * 60 * 60,
  );
  const output = await loadGeneratedOutput(userId, outputId);
  const question = extractQlinikCompatibleQuestions(output)
    .find((item) => item.id === questionId);
  if (!question) {
    throw new SafeError(
      "QUESTION_NOT_FOUND",
      "Soru bulunamadı veya bu oturuma ait değil.",
      404,
    );
  }

  const isCorrect = selectedIndex === question.correctIndex;
  await audit(
    userId,
    "submit_sourcebase_question_answer",
    "generated_output",
    outputId,
    {
      questionId,
      selectedIndex,
      isCorrect,
      elapsedSeconds,
    },
  );

  return {
    questionId,
    selectedIndex,
    isCorrect,
    correctIndex: question.correctIndex,
    explanation: question.explanation,
    optionRationales: question.optionRationales,
  };
}

async function getGeneratedAssetUrl(userId: string, payload: JsonMap) {
  const assetPath = requireString(payload.assetPath, "assetPath");
  const outputId = optionalUuid(payload.outputId, "outputId");
  if (outputId) {
    await loadGeneratedOutput(userId, outputId);
  }
  assertUserOwnedObjectName(userId, assetPath);
  const storage = getObjectStorageConfig();
  const expiresAt = new Date(Date.now() + 60 * 60 * 1000);
  const url = await createSignedReadUrl({
    storage: storage,
    objectName: assetPath,
    expiresInSeconds: 3600,
  });
  return {
    url,
    assetUrl: url,
    objectName: assetPath,
    bucket: storage.bucket,
    expiresAt: expiresAt.toISOString(),
  };
}

async function createProfileAvatarUploadSession(
  userId: string,
  payload: JsonMap,
) {
  const fileName = requireString(payload.fileName, "fileName");
  const contentType = requireString(payload.contentType, "contentType");
  const sizeBytes = Number(payload.sizeBytes ?? 0);
  const fileInfo = validateAvatarUpload(fileName, contentType, sizeBytes);

  await ensureStorageRoots(userId);
  const storage = getObjectStorageConfig();

  const safeName = sanitizeFileName(fileInfo.fileName);
  const avatarId = crypto.randomUUID();
  const objectName =
    `sourcebase/users/${userId}/profile/${avatarId}-${safeName}`;
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
  const uploadUrl = await createSignedPutUrl({
    storage: storage,
    objectName,
    expiresInSeconds: 900,
  });

  return {
    uploadUrl,
    objectName,
    bucket: storage.bucket,
    expiresAt: expiresAt.toISOString(),
    headers: { "Content-Type": fileInfo.contentType },
    metadata: {
      avatarId,
      maxSizeBytes: MAX_AVATAR_UPLOAD_BYTES,
    },
  };
}

async function completeProfileAvatarUpload(userId: string, payload: JsonMap) {
  const objectName = requireString(payload.objectName, "objectName");
  assertProfileAvatarObjectName(userId, objectName);
  const storage = getObjectStorageConfig();
  const metadata = await getObjectMetadata({
    storage: storage,
    bucket: storage.bucket,
    objectName,
  });
  assertAvatarObjectMetadata(metadata);
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  const avatarUrl = await createSignedReadUrl({
    storage: storage,
    objectName,
    expiresInSeconds: 7 * 24 * 60 * 60,
  });

  await audit(
    userId,
    "complete_profile_avatar_upload",
    "profile_avatar",
    null,
    {
      objectName,
      sizeBytes: metadata.contentLength,
      contentType: metadata.contentType,
    },
  );

  return {
    avatarUrl,
    avatar_url: avatarUrl,
    objectName,
    bucket: storage.bucket,
    expiresAt: expiresAt.toISOString(),
  };
}

async function submitSupportForm(userId: string, payload: JsonMap) {
  const topic = validateDisplayText(
    requireString(payload.topic, "topic"),
    "Konu",
    120,
  );
  const email = normalizeEmail(requireString(payload.email, "email"));
  const message = validateLongText(
    requireString(payload.message, "message"),
    "Mesaj",
    10,
    4_000,
  );

  const [ticket] = await dbInsert("support_tickets", [{
    owner_user_id: userId,
    topic,
    email,
    message,
    status: "open",
    metadata: {
      source: "sourcebase_ios",
      submittedAt: new Date().toISOString(),
    },
  }]);
  await audit(userId, "submit_support_form", "support_ticket", ticket.id, {
    topic,
  });

  return {
    ticketId: ticket.id,
    status: ticket.status ?? "open",
  };
}

async function findGeneratedOutputByJob(
  userId: string,
  fileId: string,
  kind: string,
  jobId: string,
) {
  const rows = await dbSelect(
    `generated_outputs?owner_user_id=eq.${userId}&source_file_id=eq.${fileId}&output_type=eq.${kind}&select=*&order=created_at.desc&limit=50`,
  );
  return rows.find((row) => {
    const metadata = isRecord(row.metadata) ? row.metadata : {};
    return metadata.jobId?.toString() === jobId;
  }) ?? null;
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

async function loadGeneratedOutput(userId: string, outputId: string) {
  const rows = await dbSelect(
    `generated_outputs?id=eq.${outputId}&owner_user_id=eq.${userId}&select=*&limit=1`,
  );
  const output = rows[0];
  if (!output) {
    throw new SafeError(
      "OUTPUT_NOT_FOUND",
      "Üretilen çalışma bulunamadı veya yetkin yok.",
      404,
    );
  }
  return output;
}

function extractQlinikCompatibleQuestions(
  output: JsonMap,
): CompatibleQuestion[] {
  const rawQuestions = rawQuestionItems(output);
  return rawQuestions.map((item, index) => normalizeQuestion(item, index))
    .filter((item): item is CompatibleQuestion => item !== null);
}

function rawQuestionItems(output: JsonMap): unknown[] {
  const metadata = isRecord(output.metadata) ? output.metadata : {};
  const content = metadata.content;
  if (Array.isArray(content)) return content;
  if (isRecord(content)) {
    for (const key of ["questions", "items"]) {
      const value = content[key];
      if (Array.isArray(value)) return value;
    }
  }
  if (Array.isArray(metadata.questions)) return metadata.questions;
  return [];
}

function normalizeQuestion(
  value: unknown,
  index: number,
): CompatibleQuestion | null {
  if (!isRecord(value)) return null;
  const text = firstText(value, ["text", "question", "stem"]);
  const options = stringList(value.options).slice(0, 5);
  const correctIndex = numberField(value, [
    "correctIndex",
    "correct_index",
    "answerIndex",
    "answer_index",
    "correctOptionIndex",
  ]);
  const explanation = firstText(value, [
    "explanation",
    "rationale",
    "solution",
  ]);
  if (
    !text || options.length !== 5 || correctIndex === undefined ||
    correctIndex < 0 || correctIndex > 4 || !explanation
  ) {
    return null;
  }
  const tags = stringList(value.tags);
  return {
    id: firstText(value, ["id", "questionId", "question_id"]) ||
      `question-${index}`,
    subject: firstText(value, ["subject"]) || "Kullanıcı Kaynağı",
    topic: firstText(value, ["topic"]) || "SourceBase",
    difficulty: normalizeDifficulty(firstText(value, ["difficulty"])),
    text,
    options,
    correctIndex,
    explanation,
    optionRationales: optionRationales(value),
    tags,
  };
}

function publicQuestionPrompt(question: CompatibleQuestion) {
  return {
    id: question.id,
    subject: question.subject,
    topic: question.topic,
    difficulty: question.difficulty,
    text: question.text,
    options: question.options,
    tags: question.tags,
  };
}

async function persistCandidateQuestions(
  userId: string,
  output: JsonMap,
  questions: CompatibleQuestion[],
) {
  const rawCount = rawQuestionItems(output).length;
  const allCompatible = rawCount > 0 && rawCount === questions.length;
  if (!allCompatible) {
    await audit(
      userId,
      "candidate_questions_skipped",
      "generated_output",
      output.id,
      {
        rawCount,
        compatibleCount: questions.length,
        reason: "qlinik_schema_mismatch",
      },
    );
    return;
  }

  const outputId = String(output.id ?? "");
  const sourceFileId = String(output.source_file_id ?? "");
  if (!isUuid(outputId) || !isUuid(sourceFileId)) return;

  for (const question of questions) {
    const existing = await dbSelect(
      `candidate_questions?generated_output_id=eq.${outputId}&question_id=eq.${
        encodeRestValue(question.id)
      }&select=id&limit=1`,
    );
    if (existing.length > 0) continue;
    await dbInsert("candidate_questions", [{
      owner_user_id: userId,
      source_file_id: sourceFileId,
      generated_output_id: outputId,
      question_id: question.id,
      subject: question.subject,
      topic: question.topic,
      difficulty: question.difficulty,
      question_text: question.text,
      options: question.options,
      correct_index: question.correctIndex,
      explanation: question.explanation,
      option_rationales: question.optionRationales,
      tags: question.tags,
      status: "pending_admin_review",
      metadata: {
        origin: "user_material",
        savedAt: new Date().toISOString(),
      },
    }]);
  }
}

function firstText(record: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = record[key]?.toString().replace(/\s+/g, " ").trim() ?? "";
    if (value) return value;
  }
  return "";
}

function numberField(record: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = record[key];
    const numberValue = typeof value === "number" ? value : Number(value);
    if (Number.isInteger(numberValue)) return numberValue;
  }
  return undefined;
}

function optionRationales(record: Record<string, unknown>) {
  const direct = stringList(
    record.optionRationales ?? record.option_rationales,
  );
  if (direct.length > 0) return direct.slice(0, 5);
  const rationales = record.rationales ?? record.optionExplanations ??
    record.option_explanations;
  if (Array.isArray(rationales)) return stringList(rationales).slice(0, 5);
  if (!isRecord(rationales)) return [];
  return ["A", "B", "C", "D", "E"]
    .map((key, index) =>
      firstText(rationales, [key, key.toLowerCase(), String(index)])
    )
    .filter((item) => item.length > 0);
}

function normalizeDifficulty(raw: string) {
  const value = raw.toLowerCase();
  if (["easy", "medium", "hard"].includes(value)) return value;
  if (["kolay", "temel"].includes(value)) return "easy";
  if (["zor", "ileri", "klinik"].includes(value)) return "hard";
  return "medium";
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
  const supabaseUrl = getSupabaseUrl();
  const serviceKey = getSupabaseServiceRoleKey();
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

// ===========================================================================
// Restored after the 2026-06 backend migration (these handlers were dropped
// when the live function was re-synced from an incomplete local snapshot, yet
// the iOS client still calls all three). Storage-agnostic: pure DB + shared
// MedasiCoin wallet RPCs, so safe alongside the S3 migration. See git history.
// ===========================================================================

// Save an AI output into a course/section (the "Bölüme kaydet" action).
async function moveGeneratedOutput(userId: string, payload: JsonMap) {
  const outputId = requireUuid(payload.outputId, "outputId");
  const courseId = requireUuid(payload.courseId, "courseId");
  const sectionId = requireUuid(payload.sectionId, "sectionId");
  await assertOwned(userId, "courses", courseId);
  await assertOwned(userId, "sections", sectionId);
  await assertSectionInCourse(userId, sectionId, courseId);
  await assertOwned(userId, "generated_outputs", outputId);
  const rows = await dbPatchReturning(
    "generated_outputs",
    `id=eq.${outputId}&owner_user_id=eq.${userId}`,
    {
      course_id: courseId,
      section_id: sectionId,
      updated_at: new Date().toISOString(),
    },
  );
  await audit(userId, "move_generated_output", "generated_output", outputId, {
    courseId,
    sectionId,
  });
  return { rows };
}

// File a deletion request as a support ticket (App Store account-deletion path).
async function requestAccountDeletion(
  user: { id: string; email?: string },
  payload: JsonMap,
) {
  const email = normalizeEmail(
    optionalString(payload.email) ?? user.email ?? "destek@sourcebase.local",
  );
  let ticketId: string | null = null;
  try {
    const [ticket] = await dbInsert("support_tickets", [{
      owner_user_id: user.id,
      topic: "Hesap silme talebi",
      email,
      message:
        "Kullanıcı SourceBase iOS içinden hesap silme talebi gönderdi. Kimlik ve veri silme süreci kayıtlı e-posta üzerinden takip edilmeli.",
      status: "open",
      metadata: {
        source: "account_deletion",
        submittedAt: new Date().toISOString(),
      },
    }]);
    ticketId = optionalString(ticket?.id) ?? null;
  } catch (_error) {
    // Best-effort: never block the user's deletion flow on a ticket write.
    ticketId = null;
  }
  await audit(
    user.id,
    "request_account_deletion",
    "support_ticket",
    ticketId,
    { email, stored: Boolean(ticketId) },
  );
  return { status: "received", ticketId };
}

// Redeem a verified StoreKit 2 transaction and credit MedasiCoin.
// All credited values come from the Apple-signed JWS payload — the
// client-sent productId/transactionId are treated as untrusted hints.
async function redeemAppStorePurchase(
  user: { id: string; email?: string },
  payload: JsonMap,
) {
  const jws = requireString(payload.jws, "jws");
  const expectedBundleId =
    optionalString(Deno.env.get("SOURCEBASE_APP_STORE_BUNDLE_ID")) ??
      "tr.com.medasi.sourcebase";

  let transaction: JsonMap;
  try {
    transaction = await verifyAndDecodeAppleJws(jws, appleRootCertificates());
  } catch (_error) {
    throw new SafeError(
      "APPSTORE_VERIFY_FAILED",
      "App Store satın alması doğrulanamadı.",
      400,
    );
  }

  if (optionalString(transaction.bundleId) !== expectedBundleId) {
    throw new SafeError(
      "APPSTORE_BUNDLE_MISMATCH",
      "Satın alma bu uygulamaya ait değil.",
      400,
    );
  }

  const transactionId = requireString(
    transaction.transactionId ?? transaction.originalTransactionId,
    "transactionId",
  );
  const appleProductId = requireString(transaction.productId, "productId");

  const prefix = `${expectedBundleId}.`;
  const productCode = appleProductId.startsWith(prefix)
    ? appleProductId.slice(prefix.length)
    : appleProductId;

  const product = await loadMedasiCoinProduct(productCode);
  const sharedProduct = await loadSharedMedasiCoinProduct(productCode);
  const coinUnits = productCoinUnits(sharedProduct);
  if (coinUnits <= 0 || productCode.toLowerCase().includes("subscription")) {
    throw new SafeError(
      "PRODUCT_NOT_PURCHASABLE",
      "Bu ürün App Store üzerinden coin paketi olarak satılamaz.",
      400,
    );
  }

  const providerPaymentId = `appstore:${transactionId}`;
  const existing = await dbSelect(
    `purchases?provider=eq.appstore&provider_payment_id=eq.${
      encodeURIComponent(providerPaymentId)
    }&select=id,status&limit=1`,
  );
  const beforeUnits = await sharedWalletBalanceUnits(user.id);
  await sharedRpc("grant_store_product", {
    p_user_id: user.id,
    p_product_id: requireUuid(sharedProduct.id, "shared_product_id"),
    p_provider: "appstore",
    p_provider_transaction_id: providerPaymentId,
    p_status: "active",
    p_raw_receipt: {
      app_key: "sourcebase",
      provider: "appstore",
      transactionId,
      productId: appleProductId,
      environment: optionalString(transaction.environment),
      transaction,
    },
  });
  const afterUnits = await sharedWalletBalanceUnits(user.id);

  if (existing.some((row) => row.status === "completed")) {
    return {
      status: "ok",
      alreadyProcessed: true,
      transactionId,
      productCode,
      wallet_balance: afterUnits / 100,
    };
  }

  const productId = requireUuid(product.id, "product_id");
  const priceCents = numericValue(product.price_cents) ?? 0;
  const currency = optionalString(product.currency) ?? "TRY";
  if (existing.length > 0) {
    await dbPatch(
      "purchases",
      `id=eq.${existing[0].id}`,
      { status: "completed", updated_at: new Date().toISOString() },
    );
  } else {
    await dbInsert("purchases", [{
      user_id: user.id,
      product_id: productId,
      provider: "appstore",
      provider_payment_id: providerPaymentId,
      amount_cents: priceCents,
      currency,
      status: "completed",
    }]);
  }

  await dbInsert("wallet_transactions", [{
    user_id: user.id,
    job_id: null,
    amount_mc: coinUnits / 100,
    amount_units: coinUnits,
    type: "purchase",
    reason: `appstore_purchase:${productCode}`,
    balance_before: beforeUnits / 100,
    balance_after: afterUnits / 100,
    metadata: {
      provider: "appstore",
      transactionId,
      productId: appleProductId,
      environment: optionalString(transaction.environment),
      product: medasiCoinProductSnapshot(sharedProduct, coinUnits),
    },
  }]);

  return {
    status: "ok",
    transactionId,
    productCode,
    added_mc: coinUnits / 100,
    wallet_balance: afterUnits / 100,
  };
}

// --- sourcebase-local coin product (FK target for purchases) ---
async function loadMedasiCoinProduct(productCode: string) {
  const rows = await dbSelect(
    `products?slug=eq.${
      encodeURIComponent(productCode)
    }&status=eq.published&select=*&limit=1`,
  );
  const product = rows[0];
  if (!product) {
    throw new SafeError("PRODUCT_NOT_FOUND", "Seçilen MC paketi bulunamadı.", 404);
  }
  return product;
}

// --- shared ecosystem coin product (public.store_products) ---
async function loadSharedMedasiCoinProduct(productCode: string) {
  const rows = await sharedDbSelect(
    `store_products?code=eq.${
      encodeURIComponent(productCode)
    }&is_active=eq.true&select=*&limit=1`,
  );
  const product = rows[0];
  if (!product || productCoinUnits(product) <= 0) {
    throw new SafeError(
      "SHARED_PRODUCT_NOT_FOUND",
      "Seçilen MC paketi ortak mağazada bulunamadı.",
      404,
    );
  }
  return product;
}

function medasiCoinProductSnapshot(product: JsonMap, coinUnits: number) {
  const metadata = isRecord(product.metadata) ? product.metadata : {};
  return {
    id: optionalString(product.id),
    code: optionalString(product.code) ??
      optionalString(product.slug) ??
      optionalString(metadata.code) ?? "",
    title: optionalString(product.title) ??
      optionalString(metadata.title) ??
      `${coinUnits / 100} MC Paketi`,
    price_cents: numericValue(product.price_cents) ??
      numericValue(metadata.price_cents) ?? 0,
    currency: (optionalString(product.currency) ??
      optionalString(metadata.currency) ?? "TRY").toUpperCase(),
    coin_amount: coinUnits / 100,
    amount_units: coinUnits,
  };
}

function productCoinUnits(product: JsonMap) {
  const metadata = isRecord(product.metadata) ? product.metadata : {};
  const coinAmount = numericValue(product.coin_amount) ??
    numericValue(product.coins) ??
    numericValue(product.medasicoin_amount) ??
    numericValue(metadata.coin_amount) ??
    numericValue(metadata.coins) ??
    numericValue(metadata.medasicoin_amount) ?? 0;
  return Math.max(0, Math.round(coinAmount * 100));
}

// --- shared MedasiCoin wallet (public schema, service-role) ---
async function sharedWalletBalanceUnits(userId: string) {
  const profile = await sharedRpc("sync_wallet_profile", { p_user_id: userId });
  return Math.round((numericValue(profile.wallet_balance) ?? 0) * 100);
}

async function sharedRpc(name: string, body: JsonMap): Promise<JsonMap> {
  const response = await sharedSupabaseRest(`rpc/${name}`, {
    method: "POST",
    body: JSON.stringify(body),
  });
  const data: unknown = await response.json();
  if (typeof data === "number" || typeof data === "string") {
    return { wallet_balance: Number(data) };
  }
  return isRecord(data) ? data : {};
}

async function sharedDbSelect(path: string): Promise<JsonMap[]> {
  const response = await sharedSupabaseRest(path, { method: "GET" });
  const data = await response.json();
  return Array.isArray(data) ? data.filter(isRecord) : [];
}

// Shared (public-schema) REST — for store_products + wallet RPCs used across
// the whole MedAsi ecosystem. Distinct from supabaseRest (sourcebase schema).
async function sharedSupabaseRest(path: string, init: RequestInit) {
  const supabaseUrl = getSupabaseUrl();
  const serviceKey = getSupabaseServiceRoleKey();
  if (!supabaseUrl || !serviceKey) {
    throw new SafeError(
      "DATABASE_NOT_CONFIGURED",
      "Ortak MedasiCoin veritabanı yapılandırılmamış.",
      500,
    );
  }
  const response = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: serviceKey,
      authorization: `Bearer ${serviceKey}`,
      "content-type": "application/json",
      "accept-profile": "public",
      "content-profile": "public",
      ...(init.headers ?? {}),
    },
  });
  if (!response.ok) {
    throw new SafeError(
      "DATABASE_ERROR",
      "Ortak MedasiCoin verisi işlenemedi.",
      500,
    );
  }
  return response;
}

function numericValue(value: unknown) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : undefined;
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

function requireUuid(value: unknown, name: string) {
  const text = requireString(value, name);
  if (!isUuid(text)) {
    throw new SafeError("INVALID_PAYLOAD", `${name} geçersiz.`, 400);
  }
  return text;
}

function optionalUuid(value: unknown, name: string) {
  const text = optionalString(value);
  if (!text) return undefined;
  if (!isUuid(text)) {
    throw new SafeError("INVALID_PAYLOAD", `${name} geçersiz.`, 400);
  }
  return text;
}

function requireUuidList(value: unknown, name: string) {
  const list = Array.from(new Set(requireStringList(value, name)));
  for (const item of list) {
    if (!isUuid(item)) {
      throw new SafeError("INVALID_PAYLOAD", `${name} geçersiz.`, 400);
    }
  }
  return list;
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
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

function optionalInteger(value: unknown, min: number, max: number) {
  if (value === undefined || value === null || value === "") return undefined;
  const numberValue = Number(value);
  if (
    !Number.isInteger(numberValue) || numberValue < min || numberValue > max
  ) {
    throw new SafeError("INVALID_PAYLOAD", "Süre bilgisi geçersiz.", 400);
  }
  return numberValue;
}

function validateLongText(
  text: string,
  name: string,
  minLength: number,
  maxLength: number,
) {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (normalized.length < minLength) {
    throw new SafeError("INVALID_PAYLOAD", `${name} çok kısa.`, 400);
  }
  if (normalized.length > maxLength) {
    throw new SafeError("INVALID_PAYLOAD", `${name} çok uzun.`, 400);
  }
  return normalized;
}

function normalizeEmail(value: string) {
  const email = value.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    throw new SafeError("INVALID_PAYLOAD", "E-posta adresi geçersiz.", 400);
  }
  return email;
}

function validateUploadFile(
  rawFileName: string,
  rawContentType: string,
  sizeBytes: number,
) {
  const fileName = rawFileName.replace(/\s+/g, " ").trim();
  const rawNormalizedContentType = rawContentType.toLowerCase().split(";")[0]
    .trim();
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
  const normalized = normalizeSourceFileType({
    fileName,
    contentType: rawNormalizedContentType,
  });
  if (!extension || normalized.extensionType === "unknown") {
    throw new SafeError(
      "FILE_TYPE_UNSUPPORTED",
      "Bu dosya türü desteklenmiyor. PDF, PPTX, PPT, DOCX veya DOC yükleyin.",
      400,
    );
  }
  if (!isSupportedSourceFileType(normalized.type)) {
    throw new SafeError(
      "FILE_TYPE_UNSUPPORTED",
      "Bu dosya türü desteklenmiyor. PDF, PPTX, PPT, DOCX veya DOC yükleyin.",
      400,
    );
  }
  if (
    normalized.mimeTypeType === "unknown" &&
    !normalized.isGenericMime &&
    rawNormalizedContentType
  ) {
    throw new SafeError(
      "FILE_TYPE_UNSUPPORTED",
      "Dosya MIME tipi desteklenmiyor.",
      400,
    );
  }
  const contentType = canonicalContentTypeFor(normalized.type);
  return { fileName, contentType, fileType: normalized.type };
}

function validateAvatarUpload(
  rawFileName: string,
  rawContentType: string,
  sizeBytes: number,
) {
  const fileName = rawFileName.replace(/\s+/g, " ").trim();
  const contentType = rawContentType.toLowerCase().split(";")[0].trim();
  const allowed = new Set(["image/jpeg", "image/png", "image/webp"]);
  if (
    !fileName || fileName.length > 180 || /[\\/]/.test(fileName) ||
    /[\x00-\x1F\x7F]/.test(fileName)
  ) {
    throw new SafeError(
      "INVALID_FILE_NAME",
      "Profil fotoğrafı adı geçersiz.",
      400,
    );
  }
  if (
    !Number.isFinite(sizeBytes) || sizeBytes <= 0 ||
    sizeBytes > MAX_AVATAR_UPLOAD_BYTES
  ) {
    throw new SafeError(
      "INVALID_FILE_SIZE",
      "Profil fotoğrafı en fazla 5 MB olabilir.",
      400,
    );
  }
  if (!allowed.has(contentType)) {
    throw new SafeError(
      "FILE_TYPE_UNSUPPORTED",
      "Profil fotoğrafı JPEG, PNG veya WEBP olmalı.",
      400,
    );
  }
  return { fileName, contentType };
}

function isAllowedMimeForFileType(fileType: string, contentType: string) {
  const normalized = normalizeSourceFileType({
    fileName: `source.${fileType}`,
    contentType,
  });
  return normalized.type === fileType ||
    normalized.extensionType === fileType && normalized.isGenericMime ||
    normalized.extensionType === fileType && normalized.mismatch;
}

function assertUserOwnedObjectName(userId: string, objectName: string) {
  if (
    !objectName.startsWith(`sourcebase/users/${userId}/`) ||
    objectName.includes("..")
  ) {
    throw new SafeError("FORBIDDEN_OBJECT", "Dosya yolu yetkili değil.", 403);
  }
}

function assertProfileAvatarObjectName(userId: string, objectName: string) {
  const prefix = `sourcebase/users/${userId}/profile/`;
  if (!objectName.startsWith(prefix)) {
    throw new SafeError(
      "FORBIDDEN_OBJECT",
      "Profil fotoğrafı yolu yetkili değil.",
      403,
    );
  }
  const rest = objectName.slice(prefix.length);
  const uuidLike =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const avatarId = rest.slice(0, 36);
  const separator = rest.slice(36, 37);
  const fileName = rest.slice(37);
  if (
    !uuidLike.test(avatarId) ||
    separator !== "-" ||
    !fileName ||
    fileName.includes("..")
  ) {
    throw new SafeError(
      "FORBIDDEN_OBJECT",
      "Profil fotoğrafı yolu doğrulanamadı.",
      403,
    );
  }
}

function assertAvatarObjectMetadata(metadata: StorageObjectMetadata) {
  const allowed = new Set(["image/jpeg", "image/png", "image/webp"]);
  const contentType = metadata.contentType.toLowerCase().split(";")[0].trim();
  if (!allowed.has(contentType)) {
    throw new SafeError(
      "UPLOAD_INVALID",
      "Profil fotoğrafı doğrulanamadı.",
      400,
    );
  }
  if (metadata.contentLength > MAX_AVATAR_UPLOAD_BYTES) {
    throw new SafeError(
      "INVALID_FILE_SIZE",
      "Profil fotoğrafı en fazla 5 MB olabilir.",
      400,
    );
  }
}

function assertCompletedUploadMatches(input: {
  expectedObjectName: string;
  expectedContentType: string;
  expectedFileType: string;
  expectedSizeBytes: number;
  metadata: StorageObjectMetadata;
}) {
  if (input.metadata.name !== input.expectedObjectName) {
    throw new SafeError(
      "UPLOAD_INVALID",
      "Yüklenen dosya doğrulanamadı.",
      400,
    );
  }
  if (input.metadata.contentLength !== input.expectedSizeBytes) {
    throw new SafeError(
      "UPLOAD_INVALID",
      "Yüklenen dosya doğrulanamadı.",
      400,
    );
  }
  const uploadedContentType = input.metadata.contentType.toLowerCase().split(
    ";",
  )[0].trim();
  if (!isAllowedMimeForFileType(input.expectedFileType, uploadedContentType)) {
    throw new SafeError(
      "UPLOAD_INVALID",
      "Yüklenen dosya doğrulanamadı.",
      400,
    );
  }
}

function assertUploadObjectName(
  userId: string,
  objectName: string,
  expectedSafeName: string,
) {
  const prefix = `sourcebase/users/${userId}/uploads/`;
  if (!objectName.startsWith(prefix)) {
    throw new SafeError("FORBIDDEN_OBJECT", "Dosya yolu yetkili değil.", 403);
  }
  const rest = objectName.slice(prefix.length);
  const parts = rest.split("/");
  const uuidLike =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const yearLike = /^\d{4}$/;
  const monthLike = /^(0[1-9]|1[0-2])$/;
  const filePart = parts[2] ?? "";
  const sourceId = filePart.slice(0, 36);
  const separator = filePart.slice(36, 37);
  const safeName = filePart.slice(37);
  if (
    parts.length !== 3 ||
    !yearLike.test(parts[0]) ||
    !monthLike.test(parts[1]) ||
    !uuidLike.test(sourceId) ||
    separator !== "-" ||
    safeName !== expectedSafeName
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
    examMorningSummary: "exam_morning_summary",
    exam_morning_summary: "exam_morning_summary",
    clinicalScenario: "clinical_scenario",
    clinical_scenario: "clinical_scenario",
    learningPlan: "learning_plan",
    learning_plan: "learning_plan",
    podcastSummary: "podcast_summary",
    podcast_summary: "podcast_summary",
    infographic: "infographic",
    mind_map: "mind_map",
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
    exam_morning_summary: "exam_morning_summary",
    algorithm: "algorithm",
    comparison: "comparison",
    clinical_scenario: "clinical_scenario",
    learning_plan: "learning_plan",
    podcast: "podcast",
    podcast_summary: "podcast",
    infographic: "infographic",
    mind_map: "mind_map",
    mindMap: "mind_map",
  };
  return mapping[kind];
}

function isEmptyGeneratedContent(content: unknown) {
  if (Array.isArray(content)) return content.length === 0;
  if (isRecord(content)) return Object.keys(content).length === 0;
  if (typeof content === "string") return content.trim().length === 0;
  return content === null || content === undefined;
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
    "cards",
    "flashcards",
    "must_know",
    "commonly_confused",
    "clinical_tus_tips",
    "self_check",
    "teachingPoints",
    "objectives",
    "sessions",
    "sections",
    "branches",
    "chapters",
    "days",
    "nodes",
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
    exam_morning_summary: "Sınav Sabahı Özeti",
    algorithm: "Algoritma",
    comparison: "Karşılaştırma",
    clinical_scenario: "Klinik Senaryo",
    learning_plan: "Öğrenme Planı",
    podcast: "Podcast",
    podcast_summary: "Podcast Özeti",
    infographic: "İnfografik",
    table: "Tablo",
    mind_map: "Zihin Haritası",
    mindMap: "Zihin Haritası",
  };
  return titles[kind] ?? "Üretilen İçerik";
}

function generatedCount(kind: string) {
  const counts: Record<string, number> = {
    flashcard: 125,
    question: 60,
    summary: 4,
    exam_morning_summary: 1,
    algorithm: 1,
    comparison: 1,
    clinical_scenario: 1,
    learning_plan: 1,
    podcast: 1,
    podcast_summary: 1,
    infographic: 1,
    table: 1,
    mind_map: 1,
    mindMap: 1,
  };
  return counts[kind] ?? 1;
}

function encodeRestValue(value: string) {
  return encodeURIComponent(value);
}

function allowedCorsOrigin() {
  const configured = getAllowedOrigin();
  if (!configured || configured === "*") return DEFAULT_ALLOWED_ORIGIN;
  return configured;
}

function safeGetStorageConfigForDelete() {
  try {
    return getObjectStorageConfig();
  } catch (error) {
    const safeCode = error instanceof SafeError
      ? error.code
      : "STORAGE_DELETE_CONFIG_ERROR";
    console.warn("storage delete skipped:", safeCode);
    return null;
  }
}
