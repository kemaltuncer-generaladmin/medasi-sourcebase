/**
 * SourceBase Job Processing Service
 * 
 * AI generation job'larını yönetir ve işler.
 * AGENTS.md Kural 9.4: Job status tracking
 */

import { GenerationJob, JobStatus, SafeError } from "../types.ts";

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
