/**
 * SourceBase AI Generation Actions
 *
 * Edge Function actions for AI content generation.
 * AGENTS.md Kural 11: OpenAI API key sadece server-side kullanılır.
 */

import { getVertexConfig } from "../config.ts";
import {
  GenerationJob,
  GenerationType,
  isRecord,
  requireString,
  SafeError,
} from "../types.ts";
import { JobProcessor } from "../services/job-processor.ts";
import { VertexAIClient } from "../services/vertex-ai.ts";
import {
  downloadFromGcs,
  estimateTokens,
  extractDocx,
  extractPdf,
  extractPptx,
  sanitizeSourceText,
} from "../services/extraction.ts";

const MAX_EXPLICIT_SOURCE_CHARS = 120_000;
const MAX_CHAT_MESSAGE_CHARS = 4_000;
const MAX_CHAT_CONTEXT_CHARS = 12_000;
const MAX_CONTEXT_FILES = 5;
const MAX_ACTIVE_USER_JOBS = 3;

const JOB_TYPE_ALIASES: Record<string, GenerationType> = {
  flashcard: "flashcard",
  flashcards: "flashcard",
  quiz: "quiz",
  question: "quiz",
  questions: "quiz",
  summary: "summary",
  algorithm: "algorithm",
  comparison: "comparison",
  podcast: "podcast",
  clinical_scenario: "clinical_scenario",
  clinicalScenario: "clinical_scenario",
  learning_plan: "learning_plan",
  learningPlan: "learning_plan",
  infographic: "infographic",
  mind_map: "mind_map",
  mindMap: "mind_map",
};

/**
 * Process file extraction
 * Dosyadan metin çıkarımı yapar
 */
export async function processFileExtraction(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const fileId = requireString(payload.fileId, "fileId");

  const extractionResult = await extractTextFromDriveFile(userId, fileId);

  return {
    fileId,
    textLength: extractionResult.text.length,
    pageCount: extractionResult.pageCount,
    chunkCount: extractionResult.chunks.length,
    tokenEstimate: estimateTokens(extractionResult.text),
  };
}

async function extractTextFromDriveFile(userId: string, fileId: string) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceKey) {
    throw new SafeError(
      "CONFIG_ERROR",
      "Sunucu yapılandırması eksik.",
      500,
    );
  }

  const response = await fetch(
    `${supabaseUrl}/rest/v1/drive_files?id=eq.${fileId}&owner_user_id=eq.${userId}&select=*&limit=1`,
    {
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "accept-profile": "sourcebase",
      },
    },
  );

  if (!response.ok) {
    throw new SafeError("FILE_NOT_FOUND", "Dosya bulunamadı.", 404);
  }

  const files = await response.json();
  if (!Array.isArray(files) || files.length === 0) {
    throw new SafeError("FILE_NOT_FOUND", "Dosya bulunamadı.", 404);
  }

  const file = files[0];
  const bucket = String(file.gcs_bucket ?? "");
  const objectName = String(file.gcs_object_name ?? "");
  const fileType = String(file.file_type ?? "");
  if (!bucket || !objectName || !objectName.startsWith(`user/${userId}/`)) {
    throw new SafeError(
      "FILE_STORAGE_INVALID",
      "Dosya depolama bilgisi doğrulanamadı.",
      400,
    );
  }

  const serviceAccountJson = Deno.env.get(
    "SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON",
  );
  if (!serviceAccountJson) {
    throw new SafeError("GCS_NOT_CONFIGURED", "GCS yapılandırılmamış.", 500);
  }

  const fileBuffer = await downloadFromGcs(
    bucket,
    objectName,
    serviceAccountJson,
  );

  let extractionResult;
  switch (fileType) {
    case "pdf":
      extractionResult = await extractPdf(fileBuffer);
      break;
    case "docx":
      extractionResult = await extractDocx(fileBuffer);
      break;
    case "pptx":
      extractionResult = await extractPptx(fileBuffer);
      break;
    default:
      throw new SafeError(
        "UNSUPPORTED_FILE_TYPE",
        "Bu dosya tipi desteklenmiyor.",
        400,
      );
  }

  if (!extractionResult.text.trim()) {
    throw new SafeError(
      "EXTRACTION_EMPTY",
      "Dosyadan okunabilir metin çıkarılamadı.",
      400,
    );
  }

  const updateResponse = await fetch(
    `${supabaseUrl}/rest/v1/drive_files?id=eq.${fileId}`,
    {
      method: "PATCH",
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "content-type": "application/json",
        "accept-profile": "sourcebase",
        "content-profile": "sourcebase",
      },
      body: JSON.stringify({
        page_count: extractionResult.pageCount,
        ai_status: "ready",
        metadata: {
          ...file.metadata,
          extraction: {
            textLength: extractionResult.text.length,
            chunkCount: extractionResult.chunks.length,
            extractedAt: new Date().toISOString(),
          },
        },
      }),
    },
  );
  if (!updateResponse.ok) {
    throw new SafeError(
      "FILE_UPDATE_FAILED",
      "Dosya işleme durumu güncellenemedi.",
      500,
    );
  }

  return extractionResult;
}

/**
 * Create generation job
 * AI içerik üretim işi başlatır
 */
export async function createGenerationJob(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const fileId = payload.fileId?.toString().trim() || undefined;
  const jobType = normalizeJobType(requireString(payload.jobType, "jobType"));
  const explicitSourceText = sanitizeSourceText(
    payload.sourceText?.toString() ?? "",
  );
  if (explicitSourceText.length > MAX_EXPLICIT_SOURCE_CHARS) {
    throw new SafeError(
      "SOURCE_TEXT_TOO_LARGE",
      "Kaynak metin çok uzun.",
      400,
    );
  }
  const sourceText = explicitSourceText ||
    (fileId ? (await extractTextFromDriveFile(userId, fileId)).text : "");
  if (!sourceText.trim()) {
    throw new SafeError(
      "SOURCE_TEXT_REQUIRED",
      "Kaynak metin veya dosya seçimi gerekli.",
      400,
    );
  }
  if (sourceText.length > MAX_EXPLICIT_SOURCE_CHARS) {
    throw new SafeError(
      "SOURCE_TEXT_TOO_LARGE",
      "Kaynak metin AI üretimi için çok uzun.",
      400,
    );
  }

  const count = boundedNumber(payload.count, undefined, 1, 100, "count", true);
  const temperature = boundedNumber(
    payload.temperature,
    undefined,
    0,
    1,
    "temperature",
  );
  const maxTokens = boundedNumber(
    payload.maxTokens,
    undefined,
    256,
    8192,
    "maxTokens",
    true,
  );

  const processor = createJobProcessor();
  await assertJobCapacity(processor, userId, fileId, jobType);

  const jobInput = {
    userId,
    sourceFileId: fileId,
    jobType,
    sourceText,
    options: {
      count,
      temperature,
      maxTokens,
    },
  };
  const job = await processor.createQueuedJob(jobInput);
  scheduleJobProcessing(processor, job, jobInput);

  return {
    jobId: job.id,
    status: job.status,
    jobType: job.job_type,
    createdAt: job.created_at,
  };
}

/**
 * Get job status
 * İş durumunu sorgular
 */
export async function getJobStatus(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const jobId = requireString(payload.jobId, "jobId");

  const processor = createJobProcessor();
  const job = await processor.getJobStatus(userId, jobId);

  return {
    jobId: job.id,
    status: job.status,
    jobType: job.job_type,
    inputTokens: job.input_tokens,
    outputTokens: job.output_tokens,
    costEstimate: job.cost_estimate,
    errorMessage: job.error_message,
    createdAt: job.created_at,
    updatedAt: job.updated_at,
  };
}

/**
 * Get generated content
 * Üretilen içeriği getirir
 */
export async function getGeneratedContent(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const jobId = requireString(payload.jobId, "jobId");

  const processor = createJobProcessor();
  const job = await processor.getJobStatus(userId, jobId);

  if (job.status !== "completed") {
    throw new SafeError(
      "JOB_NOT_COMPLETED",
      "İş henüz tamamlanmadı.",
      400,
    );
  }

  const metadata = isRecord(job.metadata) ? job.metadata : {};
  const content = metadata.content ?? null;

  return {
    jobId: job.id,
    jobType: job.job_type,
    content,
    inputTokens: job.input_tokens,
    outputTokens: job.output_tokens,
    costEstimate: job.cost_estimate,
  };
}

/**
 * List user jobs
 * Kullanıcının tüm işlerini listeler
 */
export async function listUserJobs(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const limit = boundedNumber(payload.limit, 50, 1, 100, "limit") ?? 50;

  const processor = createJobProcessor();
  const jobs = await processor.listUserJobs(userId, limit);

  return {
    jobs: jobs.map((job) => ({
      jobId: job.id,
      status: job.status,
      jobType: job.job_type,
      inputTokens: job.input_tokens,
      outputTokens: job.output_tokens,
      costEstimate: job.cost_estimate,
      errorMessage: job.error_message,
      createdAt: job.created_at,
      updatedAt: job.updated_at,
    })),
  };
}

/**
 * Cancel job
 * İşi iptal eder
 */
export async function cancelJob(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const jobId = requireString(payload.jobId, "jobId");

  const processor = createJobProcessor();
  await processor.cancelJob(userId, jobId);

  return {
    jobId,
    status: "cancelled",
  };
}

/**
 * Retry job
 * Başarısız işi yeniden dener
 */
export async function retryJob(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const jobId = requireString(payload.jobId, "jobId");

  const processor = createJobProcessor();
  const oldJob = await processor.getJobStatus(userId, jobId);
  if (oldJob.source_file_id) {
    const retryResult = await createGenerationJob(userId, {
      fileId: oldJob.source_file_id,
      jobType: oldJob.job_type,
    });
    const retry = isRecord(retryResult) ? retryResult : {};
    return {
      oldJobId: jobId,
      newJobId: retry.jobId,
      status: retry.status,
    };
  }
  const newJob = await processor.retryJob(userId, jobId);

  return {
    oldJobId: jobId,
    newJobId: newJob.id,
    status: newJob.status,
  };
}

/**
 * Central AI chat
 * Merkezi AI ekranı için doğrudan yanıt üretir.
 */
export async function centralAiChat(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const message = validateLength(
    requireString(payload.message, "message"),
    MAX_CHAT_MESSAGE_CHARS,
    "message",
  );
  const rawContext = sanitizeSourceText(payload.context?.toString() ?? "");
  const fileContext = await buildOwnedFileContext(userId, payload);
  const context = validateLength(
    [rawContext, fileContext].filter(Boolean).join("\n\n").trim(),
    MAX_CHAT_CONTEXT_CHARS,
    "context",
  );
  const config = createVertexConfig();
  const vertex = new VertexAIClient({
    projectId: config.vertexProjectId,
    location: config.vertexLocation,
    model: config.vertexModel,
    serviceAccountJson: config.vertexServiceAccountJson,
  });
  const reply = await vertex.generateCentralAiReply(message, context);

  return {
    message: reply.content,
    inputTokens: reply.inputTokens,
    outputTokens: reply.outputTokens,
    costEstimate: reply.costEstimate,
  };
}

/**
 * Job processor factory
 */
function createJobProcessor(): JobProcessor {
  return new JobProcessor(createVertexConfig());
}

function createVertexConfig() {
  try {
    return getVertexConfig();
  } catch (_error) {
    throw new SafeError(
      "CONFIG_ERROR",
      "AI üretim yapılandırması eksik.",
      500,
    );
  }
}

function normalizeJobType(jobType: string): GenerationType {
  const normalized = JOB_TYPE_ALIASES[jobType.trim()];
  if (!normalized) {
    throw new SafeError(
      "UNSUPPORTED_JOB_TYPE",
      "Bu üretim türü desteklenmiyor.",
      400,
    );
  }
  return normalized;
}

function boundedNumber(
  value: unknown,
  fallback: number | undefined,
  min: number,
  max: number,
  name: string,
  integer = false,
) {
  if (value === undefined || value === null || value === "") return fallback;
  const numberValue = Number(value);
  if (
    !Number.isFinite(numberValue) || numberValue < min || numberValue > max ||
    (integer && !Number.isInteger(numberValue))
  ) {
    throw new SafeError("INVALID_PAYLOAD", `${name} geçersiz.`, 400);
  }
  return numberValue;
}

function validateLength(text: string, maxLength: number, name: string) {
  if (text.length > maxLength) {
    throw new SafeError("INVALID_PAYLOAD", `${name} çok uzun.`, 400);
  }
  return text;
}

async function assertJobCapacity(
  processor: JobProcessor,
  userId: string,
  fileId: string | undefined,
  jobType: GenerationType,
) {
  const jobs = await processor.listUserJobs(userId, 50);
  const activeJobs = jobs.filter((job) =>
    job.status === "queued" || job.status === "processing"
  );
  if (activeJobs.length >= MAX_ACTIVE_USER_JOBS) {
    throw new SafeError(
      "TOO_MANY_ACTIVE_JOBS",
      "Devam eden çok fazla AI işi var.",
      429,
    );
  }
  if (
    fileId &&
    activeJobs.some((job) =>
      job.source_file_id === fileId && job.job_type === jobType
    )
  ) {
    throw new SafeError(
      "JOB_ALREADY_RUNNING",
      "Bu dosya için aynı türde bir üretim işi zaten devam ediyor.",
      409,
    );
  }
}

async function buildOwnedFileContext(
  userId: string,
  payload: Record<string, unknown>,
) {
  const rawIds = Array.isArray(payload.fileIds)
    ? payload.fileIds
    : Array.isArray(payload.contextFileIds)
    ? payload.contextFileIds
    : [];
  const fileIds = rawIds
    .map((item) => item?.toString().trim() ?? "")
    .filter(Boolean)
    .slice(0, MAX_CONTEXT_FILES);
  if (fileIds.length === 0) return "";

  const chunks: string[] = [];
  for (const fileId of fileIds) {
    const result = await extractTextFromDriveFile(userId, fileId);
    if (result.text.trim()) {
      chunks.push(result.text);
    }
  }
  return sanitizeSourceText(chunks.join("\n\n")).slice(
    0,
    MAX_CHAT_CONTEXT_CHARS,
  );
}

function scheduleJobProcessing(
  processor: JobProcessor,
  job: GenerationJob,
  input: {
    jobType: GenerationType;
    sourceText: string;
    options?: {
      count?: number;
      temperature?: number;
      maxTokens?: number;
    };
  },
) {
  const task = processor.processJob(job, input).catch((error) => {
    const safeCode = error instanceof SafeError
      ? error.code
      : "BACKGROUND_JOB_FAILED";
    console.error("AI job background processing failed:", safeCode);
  });
  const edgeRuntime = (globalThis as {
    EdgeRuntime?: { waitUntil: (promise: Promise<unknown>) => void };
  }).EdgeRuntime;
  if (edgeRuntime?.waitUntil) {
    edgeRuntime.waitUntil(task);
  }
}
