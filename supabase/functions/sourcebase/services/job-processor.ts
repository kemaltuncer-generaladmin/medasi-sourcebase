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
import { generateInfographicImage } from "./image-provider.ts";
import { captureMedasiCoin, refundMedasiCoin } from "./medasicoin-wallet.ts";
import type { McPricingQuote } from "./medasicoin-pricing.ts";
import { resolveTextRoute, RouteOptions, TextRoute } from "./model-router.ts";
import {
  GenerationOptions,
  GenerationResult,
  VertexAIClient,
} from "./vertex-ai.ts";

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
    console.error("Job update failed:", response.status);
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

type JobGenerationOptions = {
  count?: number;
  temperature?: number;
  maxTokens?: number;
  routeOptions?: RouteOptions;
  pricing?: McPricingQuote;
};

type RoutedGenerationResult<T> = GenerationResult<T> & {
  modelRoute: ReturnType<typeof safeRouteMetadata>;
};

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
    options?: JobGenerationOptions;
  }): Promise<GenerationJob> {
    const job = await this.createQueuedJob(input);
    return await this.processJob(job, input);
  }

  async createQueuedJob(input: {
    userId: string;
    sourceFileId?: string;
    jobType: GenerationType;
    sourceText: string;
    options?: JobGenerationOptions;
  }): Promise<GenerationJob> {
    const route = resolveTextRoute(
      input.jobType,
      input.options?.routeOptions,
      input.sourceText.length,
    );
    const job = await createJob(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      input.userId,
      {
        source_file_id: input.sourceFileId,
        job_type: input.jobType,
        model: route.model,
        metadata: {
          sourceTextLength: input.sourceText.length,
          modelRoute: safeRouteMetadata(route),
          pricing: input.options?.pricing,
        },
      },
    );

    return job;
  }

  async processJob(
    job: GenerationJob,
    input: {
      jobType: GenerationType;
      sourceText: string;
      options?: JobGenerationOptions;
    },
  ): Promise<GenerationJob> {
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
          model: result.modelRoute.model,
          metadata: {
            ...job.metadata,
            content: result.content,
            modelRoute: result.modelRoute,
            completedAt: new Date().toISOString(),
          },
        },
      );
      await captureMedasiCoin({
        config: this.config,
        userId: job.owner_user_id,
        jobId: job.id,
        reason: `ai_generation_capture:${input.jobType}`,
        metadata: { modelRoute: result.modelRoute },
      });
      return {
        ...job,
        status: "completed",
        input_tokens: result.inputTokens,
        output_tokens: result.outputTokens,
        cost_estimate: result.costEstimate,
        model: result.modelRoute.model,
        metadata: {
          ...job.metadata,
          content: result.content,
          modelRoute: result.modelRoute,
        },
      };
    } catch (error) {
      const pricing = isPricingQuote(job.metadata?.pricing)
        ? job.metadata.pricing
        : undefined;
      await refundMedasiCoin({
        config: this.config,
        userId: job.owner_user_id,
        jobId: job.id,
        amountUnits: pricing?.amount_units ?? 0,
        reason: `ai_generation_refund:${input.jobType}`,
        metadata: {
          errorCode: error instanceof SafeError ? error.code : "AI_FAILED",
        },
      });
      await updateJob(
        this.config.supabaseUrl,
        this.config.serviceRoleKey,
        job.id,
        {
          status: "failed",
          error_message: error instanceof SafeError
            ? error.message
            : "AI üretimi tamamlanamadı.",
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
    options: JobGenerationOptions,
  ) {
    const route = resolveTextRoute(
      jobType,
      options.routeOptions,
      sourceText.length,
    );
    const routedOptions: GenerationOptions = {
      temperature: options.temperature,
      maxTokens: options.maxTokens,
      provider: route.provider,
      model: route.model,
    };
    switch (jobType) {
      case "flashcard":
        return this.withRoute(
          route,
          this.vertex.generateFlashcards(
            sourceText,
            options.count ?? 20,
            routedOptions,
          ),
        );
      case "quiz":
        return this.withRoute(
          route,
          this.vertex.generateQuiz(
            sourceText,
            options.count ?? 10,
            routedOptions,
          ),
        );
      case "summary":
        return this.withRoute(
          route,
          this.vertex.generateSummary(sourceText, routedOptions),
        );
      case "algorithm":
        return this.withRoute(
          route,
          this.vertex.generateAlgorithm(sourceText, routedOptions),
        );
      case "comparison":
        return this.withRoute(
          route,
          this.vertex.generateComparison(sourceText, routedOptions),
        );
      case "podcast":
        return this.withRoute(
          route,
          this.vertex.generatePodcast(sourceText, routedOptions),
        );
      case "clinical_scenario":
        return this.withRoute(
          route,
          this.vertex.generateClinicalScenario(sourceText, routedOptions),
        );
      case "learning_plan":
        return this.withRoute(
          route,
          this.vertex.generateLearningPlan(sourceText, routedOptions),
        );
      case "infographic":
        return this.generateInfographicWithImage(
          sourceText,
          { ...routedOptions, routeOptions: options.routeOptions },
          route,
        );
      case "mind_map":
        return this.withRoute(
          route,
          this.vertex.generateMindMap(sourceText, routedOptions),
        );
    }
  }

  private async generateInfographicWithImage(
    sourceText: string,
    options: GenerationOptions & { routeOptions?: RouteOptions },
    route: TextRoute,
  ): Promise<RoutedGenerationResult<unknown>> {
    const specResult = await this.vertex.generateInfographic(
      sourceText,
      options,
    );
    const image = await generateInfographicImage(
      specResult.content,
      options.routeOptions,
    );
    return {
      ...specResult,
      content: {
        ...specResult.content,
        image: {
          provider: image.provider,
          model: image.model,
          mimeType: image.mimeType,
          dataUrl: image.dataUrl,
          url: image.url,
          prompt: image.prompt,
        },
      },
      modelRoute: safeRouteMetadata(route),
    };
  }

  private async withRoute<T>(
    route: TextRoute,
    result: Promise<GenerationResult<T>>,
  ): Promise<RoutedGenerationResult<T>> {
    return {
      ...await result,
      modelRoute: safeRouteMetadata(route),
    };
  }
}

function safeRouteMetadata(route: TextRoute) {
  return {
    provider: route.provider,
    model: route.model,
    tier: route.tier,
    reason: route.reason,
    fallbackUsed: route.fallbackUsed,
  };
}

function isPricingQuote(value: unknown): value is McPricingQuote {
  return typeof value === "object" && value !== null &&
    typeof (value as { amount_units?: unknown }).amount_units === "number";
}
