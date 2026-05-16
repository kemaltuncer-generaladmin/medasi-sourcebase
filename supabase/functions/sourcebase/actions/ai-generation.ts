/**
 * SourceBase AI Generation Actions
 * 
 * Edge Function actions for AI content generation.
 * AGENTS.md Kural 11: OpenAI API key sadece server-side kullanılır.
 */

import { isRecord, requireString, SafeError } from "../types.ts";
import { JobProcessor } from "../services/job-processor.ts";
import {
  chunkText,
  downloadFromGcs,
  estimateTokens,
  extractDocx,
  extractPdf,
  extractPptx,
} from "../services/extraction.ts";

/**
 * Process file extraction
 * Dosyadan metin çıkarımı yapar
 */
export async function processFileExtraction(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const fileId = requireString(payload.fileId, "fileId");

  // Dosya bilgilerini al
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

  // GCS'den dosyayı indir
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

  // Dosya tipine göre extraction
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

  // Dosya kaydını güncelle
  await fetch(
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

  return {
    fileId,
    textLength: extractionResult.text.length,
    pageCount: extractionResult.pageCount,
    chunkCount: extractionResult.chunks.length,
    tokenEstimate: estimateTokens(extractionResult.text),
  };
}

/**
 * Create generation job
 * AI içerik üretim işi başlatır
 */
export async function createGenerationJob(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const fileId = payload.fileId ? String(payload.fileId) : undefined;
  const jobType = requireString(payload.jobType, "jobType");
  const sourceText = requireString(payload.sourceText, "sourceText");

  const count = payload.count ? Number(payload.count) : undefined;
  const temperature = payload.temperature
    ? Number(payload.temperature)
    : undefined;
  const maxTokens = payload.maxTokens ? Number(payload.maxTokens) : undefined;

  // Job processor oluştur
  const processor = createJobProcessor();

  // Job başlat
  const job = await processor.createJob({
    userId,
    sourceFileId: fileId,
    jobType: jobType as any,
    sourceText,
    options: {
      count,
      temperature,
      maxTokens,
    },
  });

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
  const content = metadata.content;

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
  const limit = payload.limit ? Number(payload.limit) : 50;

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
  const newJob = await processor.retryJob(userId, jobId);

  return {
    oldJobId: jobId,
    newJobId: newJob.id,
    status: newJob.status,
  };
}

/**
 * Job processor factory
 */
function createJobProcessor(): JobProcessor {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const vertexProjectId = Deno.env.get("VERTEX_PROJECT_ID");
  const vertexLocation = Deno.env.get("VERTEX_LOCATION") ?? "us-central1";
  const vertexModel = Deno.env.get("VERTEX_MODEL") ?? "gemini-1.5-pro";
  const vertexServiceAccountJson = Deno.env.get(
    "VERTEX_SERVICE_ACCOUNT_JSON",
  );

  if (
    !supabaseUrl || !serviceRoleKey || !vertexProjectId ||
    !vertexServiceAccountJson
  ) {
    throw new SafeError(
      "CONFIG_ERROR",
      "AI üretim yapılandırması eksik.",
      500,
    );
  }

  return new JobProcessor({
    supabaseUrl,
    serviceRoleKey,
    vertexProjectId,
    vertexLocation,
    vertexModel,
    vertexServiceAccountJson,
  });
}
