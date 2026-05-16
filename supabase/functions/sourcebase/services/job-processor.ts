/**
 * SourceBase Job Processing System
 * 
 * Async AI generation job yönetimi.
 * AGENTS.md Kural 9.4: Job status tracking (queued -> processing -> completed/failed)
 */

import {
  GenerationJob,
  GenerationType,
  isRecord,
  JobStatus,
  SafeError,
} from "../types.ts";
import { VertexAIClient } from "./vertex-ai.ts";
import { sanitizeSourceText } from "./extraction.ts";

export interface JobProcessorConfig {
  supabaseUrl: string;
  serviceRoleKey: string;
  vertexProjectId: string;
  vertexLocation: string;
  vertexModel: string;
  vertexServiceAccountJson: string;
}

export interface CreateJobParams {
  userId: string;
  sourceFileId?: string;
  jobType: GenerationType;
  sourceText: string;
  options?: {
    count?: number;
    temperature?: number;
    maxTokens?: number;
  };
}

/**
 * Job Processor
 */
export class JobProcessor {
  private config: JobProcessorConfig;
  private vertexClient: VertexAIClient;

  constructor(config: JobProcessorConfig) {
    this.config = config;
    this.vertexClient = new VertexAIClient({
      projectId: config.vertexProjectId,
      location: config.vertexLocation,
      model: config.vertexModel,
      serviceAccountJson: config.vertexServiceAccountJson,
    });
  }

  /**
   * Job oluştur
   * AGENTS.md Kural 9.4: generated_jobs tablosuna kayıt
   */
  async createJob(params: CreateJobParams): Promise<GenerationJob> {
    const jobId = crypto.randomUUID();

    const jobData = {
      id: jobId,
      owner_user_id: params.userId,
      source_file_id: params.sourceFileId ?? null,
      job_type: params.jobType,
      status: "queued" as JobStatus,
      model: this.config.vertexModel,
      metadata: {
        options: params.options ?? {},
        sourceTextLength: params.sourceText.length,
      },
    };

    const [job] = await this.dbInsert("generated_jobs", [jobData]);

    // Async processing başlat (background)
    this.processJobAsync(jobId, params).catch((error) => {
      console.error(`Job ${jobId} processing error:`, error);
    });

    return job as unknown as GenerationJob;
  }

  /**
   * Job durumunu sorgula
   */
  async getJobStatus(userId: string, jobId: string): Promise<GenerationJob> {
    const jobs = await this.dbSelect(
      `generated_jobs?id=eq.${jobId}&owner_user_id=eq.${userId}&select=*&limit=1`,
    );

    if (jobs.length === 0) {
      throw new SafeError("JOB_NOT_FOUND", "İş kaydı bulunamadı.", 404);
    }

    return jobs[0] as unknown as GenerationJob;
  }

  /**
   * Kullanıcının tüm joblarını listele
   */
  async listUserJobs(
    userId: string,
    limit = 50,
  ): Promise<GenerationJob[]> {
    const jobs = await this.dbSelect(
      `generated_jobs?owner_user_id=eq.${userId}&select=*&order=created_at.desc&limit=${limit}`,
    );

    return jobs as unknown as GenerationJob[];
  }

  /**
   * Job'ı async olarak işle
   * AGENTS.md Kural 12.2: İzlenebilirlik için tüm bilgiler kaydedilir
   */
  private async processJobAsync(
    jobId: string,
    params: CreateJobParams,
  ): Promise<void> {
    try {
      // Status: processing
      await this.updateJobStatus(jobId, "processing");

      // Kaynak metni sanitize et
      // AGENTS.md Kural 12.4: Prompt injection prevention
      const sanitizedText = sanitizeSourceText(params.sourceText);

      // Token limiti kontrolü
      // AGENTS.md Kural 12.4: Token limitleri kontrol edilir (max 8K input)
      const estimatedTokens = Math.ceil(sanitizedText.length / 4);
      if (estimatedTokens > 8000) {
        throw new SafeError(
          "TEXT_TOO_LONG",
          "Kaynak metin çok uzun. Lütfen daha kısa bir metin kullanın.",
          400,
        );
      }

      // AI generation
      let result;
      const count = params.options?.count ?? 20;

      switch (params.jobType) {
        case "flashcard":
          result = await this.vertexClient.generateFlashcards(
            sanitizedText,
            count,
            params.options,
          );
          break;

        case "quiz":
          result = await this.vertexClient.generateQuiz(
            sanitizedText,
            count,
            params.options,
          );
          break;

        case "summary":
          result = await this.vertexClient.generateSummary(
            sanitizedText,
            params.options,
          );
          break;

        case "algorithm":
          result = await this.vertexClient.generateAlgorithm(
            sanitizedText,
            params.options,
          );
          break;

        case "comparison":
          result = await this.vertexClient.generateComparison(
            sanitizedText,
            params.options,
          );
          break;

        case "podcast":
          result = await this.vertexClient.generatePodcast(
            sanitizedText,
            params.options,
          );
          break;

        default:
          throw new SafeError(
            "UNSUPPORTED_JOB_TYPE",
            "Bu içerik tipi henüz desteklenmiyor.",
            400,
          );
      }

      // Job'ı tamamla
      await this.completeJob(jobId, {
        content: result.content,
        inputTokens: result.inputTokens,
        outputTokens: result.outputTokens,
        costEstimate: result.costEstimate,
      });
    } catch (error) {
      // Job'ı failed olarak işaretle
      const errorMessage = error instanceof SafeError
        ? error.message
        : "İçerik üretimi başarısız oldu.";

      await this.failJob(jobId, errorMessage);
    }
  }

  /**
   * Job status güncelle
   */
  private async updateJobStatus(
    jobId: string,
    status: JobStatus,
  ): Promise<void> {
    await this.dbUpdate("generated_jobs", jobId, {
      status,
      updated_at: new Date().toISOString(),
    });
  }

  /**
   * Job'ı tamamla
   */
  private async completeJob(
    jobId: string,
    result: {
      content: unknown;
      inputTokens: number;
      outputTokens: number;
      costEstimate: number;
    },
  ): Promise<void> {
    await this.dbUpdate("generated_jobs", jobId, {
      status: "completed" as JobStatus,
      input_tokens: result.inputTokens,
      output_tokens: result.outputTokens,
      cost_estimate: result.costEstimate,
      metadata: { content: result.content },
      updated_at: new Date().toISOString(),
    });
  }

  /**
   * Job'ı failed olarak işaretle
   */
  private async failJob(jobId: string, errorMessage: string): Promise<void> {
    await this.dbUpdate("generated_jobs", jobId, {
      status: "failed" as JobStatus,
      error_message: errorMessage,
      updated_at: new Date().toISOString(),
    });
  }

  /**
   * Job'ı iptal et
   */
  async cancelJob(userId: string, jobId: string): Promise<void> {
    const job = await this.getJobStatus(userId, jobId);

    if (job.status === "completed" || job.status === "failed") {
      throw new SafeError(
        "JOB_ALREADY_FINISHED",
        "Bu iş zaten tamamlanmış.",
        400,
      );
    }

    await this.dbUpdate("generated_jobs", jobId, {
      status: "cancelled" as JobStatus,
      updated_at: new Date().toISOString(),
    });
  }

  /**
   * Retry logic
   * AGENTS.md Kural 10.3: Error handling ve retry logic
   */
  async retryJob(userId: string, jobId: string): Promise<GenerationJob> {
    const oldJob = await this.getJobStatus(userId, jobId);

    if (oldJob.status !== "failed") {
      throw new SafeError(
        "JOB_NOT_FAILED",
        "Sadece başarısız işler yeniden denenebilir.",
        400,
      );
    }

    // Yeni job oluştur
    const sourceText = String(
      (oldJob.metadata as Record<string, unknown>)?.sourceText ?? "",
    );
    const options = (oldJob.metadata as Record<string, unknown>)?.options as
      | Record<string, unknown>
      | undefined;

    return await this.createJob({
      userId,
      sourceFileId: oldJob.source_file_id ?? undefined,
      jobType: oldJob.job_type,
      sourceText,
      options: options as CreateJobParams["options"],
    });
  }

  /**
   * Database helpers
   */
  private async dbSelect(path: string): Promise<Record<string, unknown>[]> {
    const response = await this.supabaseRest(path, { method: "GET" });
    const data = await response.json();
    return Array.isArray(data) ? data.filter(isRecord) : [];
  }

  private async dbInsert(
    table: string,
    rows: Record<string, unknown>[],
  ): Promise<Record<string, unknown>[]> {
    const response = await this.supabaseRest(table, {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify(rows),
    });
    const data = await response.json();
    return Array.isArray(data) ? data.filter(isRecord) : [];
  }

  private async dbUpdate(
    table: string,
    id: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    await this.supabaseRest(`${table}?id=eq.${id}`, {
      method: "PATCH",
      body: JSON.stringify(data),
    });
  }

  private async supabaseRest(
    path: string,
    init: RequestInit,
  ): Promise<Response> {
    const response = await fetch(
      `${this.config.supabaseUrl}/rest/v1/${path}`,
      {
        ...init,
        headers: {
          apikey: this.config.serviceRoleKey,
          authorization: `Bearer ${this.config.serviceRoleKey}`,
          "content-type": "application/json",
          "accept-profile": "sourcebase",
          "content-profile": "sourcebase",
          ...(init.headers ?? {}),
        },
      },
    );

    if (!response.ok) {
      throw new SafeError(
        "DATABASE_ERROR",
        "Veritabanı işlemi başarısız.",
        500,
      );
    }

    return response;
  }
}
