/**
 * SourceBase AI Generation Actions
 *
 * Edge Function actions for AI content generation.
 * AGENTS.md Kural 11: OpenAI API key sadece server-side kullanılır.
 */

import {
  getGcsConfig,
  getSupabaseServiceRoleKey,
  getSupabaseUrl,
  getVertexConfig,
} from "../config.ts";
import {
  GenerationJob,
  GenerationType,
  isRecord,
  requireString,
  SafeError,
} from "../types.ts";
import { logAiPipeline } from "../services/ai-logger.ts";
import {
  JobGenerationOptions,
  JobProcessor,
} from "../services/job-processor.ts";
import type { McPricingQuote } from "../services/medasicoin-pricing.ts";
import {
  estimateGenerationPricing,
  normalizeQualityTier,
} from "../services/medasicoin-pricing.ts";
import {
  captureMedasiCoin,
  getWalletBalance,
  refundMedasiCoin,
  reserveMedasiCoin,
} from "../services/medasicoin-wallet.ts";
import {
  resolveTextRoute,
  routeOptionsFromPayload,
} from "../services/model-router.ts";
import { VertexAIClient } from "../services/vertex-ai.ts";
import {
  downloadFromGcs,
  estimateTokens,
  extractDocx,
  extractPdf,
  extractPptx,
  sanitizeSourceText,
} from "../services/extraction.ts";
import {
  normalizeSourceFileType,
  userMessageForLimitedLegacyType,
} from "../services/file-types.ts";

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
  exam_morning_summary: "exam_morning_summary",
  examMorningSummary: "exam_morning_summary",
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
  const fileId = requireUuid(payload.fileId, "fileId");

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
  const supabaseUrl = getSupabaseUrl();
  const serviceKey = getSupabaseServiceRoleKey();

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
  const normalizedFileType = normalizeSourceFileType({
    fileName: String(file.original_filename ?? file.title ?? objectName),
    contentType: String(file.mime_type ?? ""),
  });
  const storedFileType = String(file.file_type ?? "").trim().toLowerCase();
  const storedFileTypeInfo = normalizeSourceFileType({
    fileName: storedFileType.includes("/") ? "" : `source.${storedFileType}`,
    contentType: storedFileType.includes("/") ? storedFileType : "",
  });
  const fileType = normalizedFileType.type !== "unknown"
    ? normalizedFileType.type
    : storedFileTypeInfo.type;
  if (!bucket || !objectName || !objectName.startsWith(`user/${userId}/`)) {
    throw new SafeError(
      "FILE_STORAGE_INVALID",
      "Dosya depolama bilgisi doğrulanamadı.",
      400,
    );
  }

  let serviceAccountJson = "";
  try {
    serviceAccountJson = getGcsConfig().serviceAccountJson;
  } catch (_error) {
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
    case "ppt":
      throw new SafeError(
        "FILE_TYPE_LIMITED_SUPPORT",
        userMessageForLimitedLegacyType("ppt"),
        400,
      );
    case "doc":
      throw new SafeError(
        "FILE_TYPE_LIMITED_SUPPORT",
        userMessageForLimitedLegacyType("doc"),
        400,
      );
    default:
      throw new SafeError(
        "FILE_TYPE_UNSUPPORTED",
        "Bu dosya türü desteklenmiyor. PDF, PPTX, PPT, DOCX veya DOC yükleyin.",
        400,
      );
  }

  if (!extractionResult.text.trim()) {
    throw new SafeError(
      "FILE_TEXT_EMPTY",
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
  const fileId = optionalUuid(payload.fileId, "fileId");
  const jobType = normalizeJobType(requireString(payload.jobType, "jobType"));
  logAiPipeline({
    action: "create_generation_job",
    status: "received",
    jobType,
  });
  if (fileId) {
    await assertDriveFileOwned(userId, fileId);
  }
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
  const routeOptions = routeOptionsFromPayload(payload);
  const qualityTier = normalizeQualityTier(payload.quality_tier);
  const pricing = estimateGenerationPricing({
    jobType,
    sourceTextLength: sourceText.length,
    maxTokens,
    count,
    qualityTier,
    routeOptions,
  });
  const config = createVertexConfig();
  const walletConfig = {
    supabaseUrl: config.supabaseUrl,
    serviceRoleKey: config.serviceRoleKey,
  };
  const balance = await getWalletBalance(walletConfig, userId);
  if (balance.balance_units < pricing.amount_units) {
    throw new SafeError(
      "INSUFFICIENT_MC",
      "Yetersiz MedasiCoin bakiyesi.",
      402,
    );
  }

  const processor = new JobProcessor(config);
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
      routeOptions,
      pricing,
      summaryMode: textOption(payload.summary_mode),
      lengthTarget: textOption(payload.length_target),
      outputFormat: textOption(payload.output_format),
      algorithmType: textOption(payload.algorithm_type),
      comparisonType: textOption(payload.comparison_type),
      tableFormat: textOption(payload.table_format),
      detailLevel: textOption(payload.detail_level),
      infographicType: textOption(payload.infographic_type),
      visualStyle: textOption(payload.visual_style),
      density: textOption(payload.density),
      mapType: textOption(payload.map_type),
      depth: textOption(payload.depth),
      viewMode: textOption(payload.view_mode),
      scenarioType: textOption(payload.scenario_type),
      difficulty: textOption(payload.difficulty),
      planGoal: textOption(payload.plan_goal),
      dailyTime: textOption(payload.daily_time),
      studyStyle: textOption(payload.study_style),
      qualityTier,
    },
  };
  const job = await processor.createQueuedJob(jobInput);
  logAiPipeline({
    action: "create_generation_job",
    status: "queued",
    jobId: job.id,
    jobType,
    provider: job.metadata?.modelRoute && isRecord(job.metadata.modelRoute)
      ? job.metadata.modelRoute.provider?.toString()
      : undefined,
    model: job.model,
  });
  const reservation = await reserveMedasiCoin({
    config: walletConfig,
    userId,
    jobId: job.id,
    quote: pricing,
    reason: `ai_generation:${jobType}`,
  });

  return {
    jobId: job.id,
    status: job.status,
    jobType: job.job_type,
    createdAt: job.created_at,
    ...pricing,
    balance_before: reservation.balance_before,
    balance_after_reserve: reservation.balance_after_reserve,
  };
}

export async function processGenerationJob(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const jobId = requireUuid(payload.jobId, "jobId");
  logAiPipeline({
    action: "process_generation_job",
    status: "received",
    jobId,
  });

  const processor = createJobProcessor();
  const job = await processor.getJobStatus(userId, jobId);
  if (job.status === "completed") {
    return {
      jobId: job.id,
      status: job.status,
      jobType: job.job_type,
      alreadyCompleted: true,
    };
  }
  if (job.status === "cancelled") {
    throw new SafeError("JOB_CANCELLED", "İş iptal edilmiş.", 400);
  }
  if (job.status === "failed") {
    const metadata = isRecord(job.metadata) ? job.metadata : {};
    throw new SafeError(
      metadata.errorCode?.toString() || "JOB_ALREADY_FAILED",
      job.error_message || "AI üretimi tamamlanamadı.",
      400,
    );
  }

  const sourceText = await sourceTextForJob(userId, job);
  const processed = await processor.processJob(job, {
    jobType: job.job_type,
    sourceText,
    options: generationOptionsFromJob(job.metadata),
  });

  return {
    jobId: processed.id,
    status: processed.status,
    jobType: processed.job_type,
    inputTokens: processed.input_tokens,
    outputTokens: processed.output_tokens,
    costEstimate: processed.cost_estimate,
  };
}

async function sourceTextForJob(userId: string, job: GenerationJob) {
  if (job.source_file_id) {
    return (await extractTextFromDriveFile(userId, job.source_file_id)).text;
  }
  const metadata = isRecord(job.metadata) ? job.metadata : {};
  const sourceText = sanitizeSourceText(metadata.sourceText?.toString() ?? "");
  if (sourceText.trim()) return sourceText;
  throw new SafeError(
    "SOURCE_TEXT_REQUIRED",
    "Üretim işi için kaynak metin bulunamadı.",
    400,
  );
}

function generationOptionsFromJob(
  metadataValue: unknown,
): JobGenerationOptions {
  const metadata = isRecord(metadataValue) ? metadataValue : {};
  const options = isRecord(metadata.generationOptions)
    ? metadata.generationOptions
    : {};
  return {
    count: numericOption(options.count),
    temperature: numericOption(options.temperature),
    maxTokens: numericOption(options.maxTokens),
    routeOptions: isRecord(options.routeOptions) ? options.routeOptions : {},
    pricing: isRecord(metadata.pricing)
      ? metadata.pricing as unknown as McPricingQuote
      : undefined,
    summaryMode: textOption(options.summaryMode),
    lengthTarget: textOption(options.lengthTarget),
    outputFormat: textOption(options.outputFormat),
    algorithmType: textOption(options.algorithmType),
    comparisonType: textOption(options.comparisonType),
    tableFormat: textOption(options.tableFormat),
    detailLevel: textOption(options.detailLevel),
    infographicType: textOption(options.infographicType),
    visualStyle: textOption(options.visualStyle),
    density: textOption(options.density),
    mapType: textOption(options.mapType),
    depth: textOption(options.depth),
    viewMode: textOption(options.viewMode),
    scenarioType: textOption(options.scenarioType),
    difficulty: textOption(options.difficulty),
    planGoal: textOption(options.planGoal),
    dailyTime: textOption(options.dailyTime),
    studyStyle: textOption(options.studyStyle),
    qualityTier: textOption(options.qualityTier),
  };
}

export async function estimateGenerationCost(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const rawJobType = requireString(payload.jobType, "jobType");
  const jobType =
    rawJobType === "central_ai" || rawJobType === "central_ai_chat"
      ? "central_ai"
      : normalizeJobType(rawJobType);
  const sourceText = sanitizeSourceText(payload.sourceText?.toString() ?? "");
  const sourceTextLength = sourceText.length ||
    boundedNumber(
      payload.sourceTextLength,
      0,
      0,
      MAX_EXPLICIT_SOURCE_CHARS,
      "sourceTextLength",
      true,
    ) ||
    0;
  const maxTokens = boundedNumber(
    payload.maxTokens,
    undefined,
    256,
    8192,
    "maxTokens",
    true,
  );
  const count = boundedNumber(payload.count, undefined, 1, 100, "count", true);
  const routeOptions = routeOptionsFromPayload(payload);
  const qualityTier = normalizeQualityTier(payload.quality_tier);
  const pricing = estimateGenerationPricing({
    jobType,
    sourceTextLength,
    maxTokens,
    count,
    qualityTier,
    routeOptions,
  });
  const config = createVertexConfig();
  const balance = await getWalletBalance({
    supabaseUrl: config.supabaseUrl,
    serviceRoleKey: config.serviceRoleKey,
  }, userId);
  return {
    ...pricing,
    can_afford: balance.balance_units >= pricing.amount_units,
    current_balance: balance.balance_mc,
    balance_after: (balance.balance_units - pricing.amount_units) / 100,
    explanation:
      "AI maliyeti gerçek sağlayıcı tahmini + hedef brüt marj ile hesaplandı.",
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
  const jobId = requireUuid(payload.jobId, "jobId");

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
    errorCode: isRecord(job.metadata) ? job.metadata.errorCode : undefined,
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
  const jobId = requireUuid(payload.jobId, "jobId");

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
  const jobId = requireUuid(payload.jobId, "jobId");

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
  const jobId = requireUuid(payload.jobId, "jobId");

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
  const routeOptions = routeOptionsFromPayload(payload);
  const qualityTier = normalizeQualityTier(payload.quality_tier);
  const pricing = estimateGenerationPricing({
    jobType: "central_ai",
    sourceTextLength: context.length + message.length,
    maxTokens: boundedNumber(
      payload.maxTokens,
      undefined,
      256,
      4096,
      "maxTokens",
      true,
    ),
    qualityTier,
    routeOptions,
  });
  const walletConfig = {
    supabaseUrl: config.supabaseUrl,
    serviceRoleKey: config.serviceRoleKey,
  };
  const balance = await getWalletBalance(walletConfig, userId);
  if (balance.balance_units < pricing.amount_units) {
    throw new SafeError(
      "INSUFFICIENT_MC",
      "Yetersiz MedasiCoin bakiyesi.",
      402,
    );
  }
  const reservation = await reserveMedasiCoin({
    config: walletConfig,
    userId,
    quote: pricing,
    reason: "central_ai_chat",
  });
  const vertex = new VertexAIClient({
    projectId: config.vertexProjectId,
    location: config.vertexLocation,
    model: config.vertexModel,
    serviceAccountJson: config.vertexServiceAccountJson,
  });
  const route = resolveTextRoute(
    "central_ai_chat",
    routeOptions,
    context.length + message.length,
  );
  try {
    const reply = await vertex.generateCentralAiReply(message, context, {
      provider: route.provider,
      model: route.model,
    });
    await captureMedasiCoin({
      config: walletConfig,
      userId,
      reason: "central_ai_chat_capture",
      metadata: { pricing, modelRoute: pricing.route },
    });

    return {
      message: reply.content,
      inputTokens: reply.inputTokens,
      outputTokens: reply.outputTokens,
      costEstimate: reply.costEstimate,
      modelRoute: {
        provider: route.provider,
        model: route.model,
        tier: route.tier,
        reason: route.reason,
        fallbackUsed: route.fallbackUsed,
      },
      ...pricing,
      balance_before: reservation.balance_before,
      balance_after_reserve: reservation.balance_after_reserve,
    };
  } catch (error) {
    await refundMedasiCoin({
      config: walletConfig,
      userId,
      amountUnits: pricing.amount_units,
      reason: "central_ai_chat_refund",
      metadata: {
        errorCode: error instanceof SafeError
          ? error.code
          : "CENTRAL_AI_FAILED",
      },
    });
    throw error;
  }
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
  } catch (error) {
    if (error instanceof SafeError) {
      throw error;
    }
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

function requireUuid(value: unknown, name: string) {
  const text = requireString(value, name);
  if (!isUuid(text)) {
    throw new SafeError("INVALID_PAYLOAD", `${name} geçersiz.`, 400);
  }
  return text;
}

function optionalUuid(value: unknown, name: string) {
  const text = value?.toString().trim() ?? "";
  if (!text) return undefined;
  if (!isUuid(text)) {
    throw new SafeError("INVALID_PAYLOAD", `${name} geçersiz.`, 400);
  }
  return text;
}

function textOption(value: unknown) {
  const text = value?.toString().trim() ?? "";
  return text || undefined;
}

function numericOption(value: unknown) {
  if (value === undefined || value === null || value === "") return undefined;
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : undefined;
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

async function assertDriveFileOwned(userId: string, fileId: string) {
  const supabaseUrl = getSupabaseUrl();
  const serviceKey = getSupabaseServiceRoleKey();
  if (!supabaseUrl || !serviceKey) {
    throw new SafeError(
      "CONFIG_ERROR",
      "Sunucu yapılandırması eksik.",
      500,
    );
  }
  const response = await fetch(
    `${supabaseUrl}/rest/v1/drive_files?id=eq.${fileId}&owner_user_id=eq.${userId}&select=id,status,ai_status,size_bytes&limit=1`,
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
  const rows = await response.json();
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new SafeError("FILE_NOT_FOUND", "Dosya bulunamadı.", 404);
  }
  const row = rows[0];
  const status = String(row.status ?? "").toLowerCase();
  const aiStatus = String(row.ai_status ?? "").toLowerCase();
  const sizeBytes = Number(row.size_bytes ?? 0);
  if (!Number.isFinite(sizeBytes) || sizeBytes <= 0) {
    throw new SafeError(
      "FILE_OBJECT_EMPTY",
      "Yüklenen dosya boş görünüyor.",
      400,
    );
  }
  if (status === "draft" || aiStatus === "draft") {
    throw new SafeError(
      "FILE_NOT_READY",
      "Taslak kaynaklarla üretim başlatılamaz.",
      400,
    );
  }
  if (status === "failed" || aiStatus === "failed" || aiStatus === "error") {
    throw new SafeError(
      "FILE_NOT_READY",
      "Bu dosyada işleme hatası var.",
      400,
    );
  }
  if (aiStatus && aiStatus !== "ready" && aiStatus !== "completed") {
    throw new SafeError(
      "FILE_NOT_READY",
      "Bu dosya henüz işleniyor.",
      400,
    );
  }
  if (!aiStatus && status !== "ready" && status !== "completed") {
    throw new SafeError(
      "FILE_NOT_READY",
      "Bu dosya henüz işleniyor.",
      400,
    );
  }
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
  const parsedIds = rawIds
    .map((item) => item?.toString().trim() ?? "")
    .filter((item) => item.length > 0);
  for (const fileId of parsedIds) {
    if (!isUuid(fileId)) {
      throw new SafeError("INVALID_PAYLOAD", "fileIds geçersiz.", 400);
    }
  }
  const fileIds = Array.from(new Set(parsedIds)).slice(0, MAX_CONTEXT_FILES);
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
