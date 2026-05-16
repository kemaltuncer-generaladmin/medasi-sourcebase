/**
 * SourceBase Job Processing Service
 *
 * AI generation job'larını yönetir ve işler.
 * AGENTS.md Kural 9.4: Job status tracking
 */

import {
  GenerationJob,
  GenerationType,
  JobStatus,
  SafeError,
} from "../types.ts";
import { VertexAIClient } from "./vertex-ai.ts";

export interface JobUpdate {
  status?: JobStatus;
  model?: string;
  input_tokens?: number;
  output_tokens?: number;
  cost_estimate?: number;
  error_message?: string;
  metadata?: Record<string, unknown>;
}

/**
 * Job oluştur
 */
export async function createJob(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
  jobData: {
    source_file_id?: string;
    source_id?: string;
    deck_id?: string;
    job_type: string;
    model?: string;
    metadata?: Record<string, unknown>;
  },
): Promise<GenerationJob> {
  const response = await fetch(`${supabaseUrl}/rest/v1/generated_jobs`, {
    method: "POST",
    headers: {
      "apikey": serviceRoleKey,
      "authorization": `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
      "accept-profile": "sourcebase",
      "content-profile": "sourcebase",
      "prefer": "return=representation",
    },
    body: JSON.stringify({
      owner_user_id: userId,
      source_file_id: jobData.source_file_id,
      source_id: jobData.source_id,
      deck_id: jobData.deck_id,
      job_type: jobData.job_type,
      status: "queued",
      model: jobData.model,
      metadata: jobData.metadata || {},
    }),
  });

  if (!response.ok) {
    throw new SafeError("JOB_CREATE_FAILED", "İş oluşturulamadı.", 500);
  }

  const jobs = await response.json();
  if (!Array.isArray(jobs) || jobs.length === 0) {
    throw new SafeError("JOB_CREATE_FAILED", "İş oluşturulamadı.", 500);
  }

  return jobs[0] as GenerationJob;
}

/**
 * Job durumunu güncelle
 */
export async function updateJob(
  supabaseUrl: string,
  serviceRoleKey: string,
  jobId: string,
  updates: JobUpdate,
): Promise<void> {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/generated_jobs?id=eq.${jobId}`,
    {
      method: "PATCH",
      headers: {
        "apikey": serviceRoleKey,
        "authorization": `Bearer ${serviceRoleKey}`,
        "content-type": "application/json",
        "accept-profile": "sourcebase",
        "content-profile": "sourcebase",
      },
      body: JSON.stringify({
        ...updates,
        updated_at: new Date().toISOString(),
      }),
    },
  );

  if (!response.ok) {
    console.error("Job update failed:", await response.text());
  }
}

/**
 * Job'ı getir
 */
export async function getJob(
  supabaseUrl: string,
  serviceRoleKey: string,
  jobId: string,
  userId: string,
): Promise<GenerationJob | null> {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/generated_jobs?id=eq.${jobId}&owner_user_id=eq.${userId}&select=*`,
    {
      method: "GET",
      headers: {
        "apikey": serviceRoleKey,
        "authorization": `Bearer ${serviceRoleKey}`,
        "accept-profile": "sourcebase",
        "content-profile": "sourcebase",
      },
    },
  );

  if (!response.ok) {
    return null;
  }

  const jobs = await response.json();
  if (!Array.isArray(jobs) || jobs.length === 0) {
    return null;
  }

  return jobs[0] as GenerationJob;
}

/**
 * Kullanıcının job'larını listele
 */
export async function listJobs(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
  limit = 50,
): Promise<GenerationJob[]> {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/generated_jobs?owner_user_id=eq.${userId}&select=*&order=created_at.desc&limit=${limit}`,
    {
      method: "GET",
      headers: {
        "apikey": serviceRoleKey,
        "authorization": `Bearer ${serviceRoleKey}`,
        "accept-profile": "sourcebase",
        "content-profile": "sourcebase",
      },
    },
  );

  if (!response.ok) {
    return [];
  }

  const jobs = await response.json();
  return Array.isArray(jobs) ? jobs : [];
}

/**
 * Job'ı iptal et
 */
export async function cancelJob(
  supabaseUrl: string,
  serviceRoleKey: string,
  jobId: string,
  userId: string,
): Promise<boolean> {
  const job = await getJob(supabaseUrl, serviceRoleKey, jobId, userId);
  if (!job) {
    return false;
  }

  if (job.status === "completed" || job.status === "cancelled") {
    return false;
  }

  await updateJob(supabaseUrl, serviceRoleKey, jobId, {
    status: "cancelled",
  });

  return true;
}

export interface JobProcessorConfig {
  supabaseUrl: string;
  serviceRoleKey: string;
  vertexProjectId: string;
  vertexLocation: string;
  vertexModel: string;
  vertexServiceAccountJson: string;
}

export class JobProcessor {
  private vertex: VertexAIClient;

  constructor(private config: JobProcessorConfig) {
    this.vertex = new VertexAIClient({
      projectId: config.vertexProjectId,
      location: config.vertexLocation,
      model: config.vertexModel,
      serviceAccountJson: config.vertexServiceAccountJson,
    });
  }

  async createJob(input: {
    userId: string;
    sourceFileId?: string;
    jobType: GenerationType;
    sourceText: string;
    options?: {
      count?: number;
      temperature?: number;
      maxTokens?: number;
    };
  }): Promise<GenerationJob> {
    const job = await createJob(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      input.userId,
      {
        source_file_id: input.sourceFileId,
        job_type: input.jobType,
        model: this.config.vertexModel,
        metadata: { sourceTextLength: input.sourceText.length },
      },
    );

    await updateJob(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      job.id,
      {
        status: "processing",
      },
    );

    try {
      const result = await this.generate(
        input.jobType,
        input.sourceText,
        input.options ?? {},
      );
      await updateJob(
        this.config.supabaseUrl,
        this.config.serviceRoleKey,
        job.id,
        {
          status: "completed",
          input_tokens: result.inputTokens,
          output_tokens: result.outputTokens,
          cost_estimate: result.costEstimate,
          metadata: {
            ...job.metadata,
            content: result.content,
            completedAt: new Date().toISOString(),
          },
        },
      );
      return {
        ...job,
        status: "completed",
        input_tokens: result.inputTokens,
        output_tokens: result.outputTokens,
        cost_estimate: result.costEstimate,
        metadata: {
          ...job.metadata,
          content: result.content,
        },
      };
    } catch (error) {
      await updateJob(
        this.config.supabaseUrl,
        this.config.serviceRoleKey,
        job.id,
        {
          status: "failed",
          error_message: error instanceof Error ? error.message : "Job failed.",
        },
      );
      throw error;
    }
  }

  async getJobStatus(userId: string, jobId: string): Promise<GenerationJob> {
    const job = await getJob(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      jobId,
      userId,
    );
    if (!job) {
      throw new SafeError("JOB_NOT_FOUND", "İş bulunamadı.", 404);
    }
    return job;
  }

  listUserJobs(userId: string, limit = 50): Promise<GenerationJob[]> {
    return listJobs(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      userId,
      limit,
    );
  }

  async cancelJob(userId: string, jobId: string): Promise<void> {
    const ok = await cancelJob(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      jobId,
      userId,
    );
    if (!ok) {
      throw new SafeError("JOB_NOT_CANCELLED", "İş iptal edilemedi.", 400);
    }
  }

  async retryJob(userId: string, jobId: string): Promise<GenerationJob> {
    const oldJob = await this.getJobStatus(userId, jobId);
    const metadata = oldJob.metadata ?? {};
    const sourceText = metadata.sourceText?.toString() ??
      metadata.sourceTextPreview?.toString() ??
      "";
    if (!sourceText.trim()) {
      throw new SafeError(
        "SOURCE_TEXT_REQUIRED",
        "Yeniden deneme için kaynak metin bulunamadı.",
        400,
      );
    }
    return this.createJob({
      userId,
      sourceFileId: oldJob.source_file_id,
      jobType: oldJob.job_type,
      sourceText,
    });
  }

  private generate(
    jobType: GenerationType,
    sourceText: string,
    options: { count?: number; temperature?: number; maxTokens?: number },
  ) {
    switch (jobType) {
      case "flashcard":
        return this.vertex.generateFlashcards(
          sourceText,
          options.count ?? 20,
          options,
        );
      case "quiz":
        return this.vertex.generateQuiz(
          sourceText,
          options.count ?? 10,
          options,
        );
      case "summary":
        return this.vertex.generateSummary(sourceText, options);
      case "algorithm":
        return this.vertex.generateAlgorithm(sourceText, options);
      case "comparison":
        return this.vertex.generateComparison(sourceText, options);
      case "podcast":
        return this.vertex.generatePodcast(sourceText, options);
    }
  }
}
