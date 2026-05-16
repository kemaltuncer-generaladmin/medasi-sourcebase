/**
 * SourceBase Shared Types
 * 
 * Edge Function genelinde kullanılan tip tanımları ve yardımcı sınıflar.
 */

export type JsonMap = Record<string, unknown>;

/**
 * Güvenli hata sınıfı
 * AGENTS.md Kural 18: Hata mesajları kullanıcıya hassas bilgi sızdırmadan döndürülür
 */
export class SafeError extends Error {
  constructor(
    public code: string,
    message: string,
    public status = 400,
  ) {
    super(message);
  }
}

/**
 * AI Generation Job Status
 */
export type JobStatus =
  | "queued"
  | "processing"
  | "completed"
  | "failed"
  | "cancelled";

/**
 * Content Generation Types
 */
export type GenerationType =
  | "flashcard"
  | "quiz"
  | "summary"
  | "algorithm"
  | "comparison"
  | "podcast"
  | "table"
  | "mindmap";

/**
 * AI Model Provider
 */
export type AIProvider = "vertex" | "openai";

/**
 * Generation Job Record
 */
export interface GenerationJob {
  id: string;
  owner_user_id: string;
  source_file_id?: string;
  job_type: GenerationType;
  status: JobStatus;
  model?: string;
  input_tokens?: number;
  output_tokens?: number;
  cost_estimate?: number;
  error_message?: string;
  metadata: JsonMap;
  created_at: string;
  updated_at: string;
}

/**
 * Flashcard Structure
 */
export interface Flashcard {
  front: string;
  back: string;
  explanation?: string;
  tags?: string[];
  difficulty?: "easy" | "medium" | "hard";
}

/**
 * Quiz Question Structure
 */
export interface QuizQuestion {
  question: string;
  options: string[];
  correctIndex: number;
  explanation: string;
  difficulty?: "easy" | "medium" | "hard";
  tags?: string[];
}

/**
 * Summary Structure
 */
export interface Summary {
  bulletPoints: string[];
  fullText: string;
  keyTerms?: string[];
  mainTopics?: string[];
}

/**
 * Algorithm Structure
 */
export interface Algorithm {
  title: string;
  steps: AlgorithmStep[];
  notes?: string[];
}

export interface AlgorithmStep {
  stepNumber: number;
  title: string;
  description: string;
  substeps?: string[];
}

/**
 * Comparison Table Structure
 */
export interface ComparisonTable {
  title: string;
  headers: string[];
  rows: ComparisonRow[];
}

export interface ComparisonRow {
  label: string;
  values: string[];
}

/**
 * Podcast Script Structure
 */
export interface PodcastScript {
  title: string;
  duration: string;
  segments: PodcastSegment[];
}

export interface PodcastSegment {
  speaker: "host" | "expert";
  text: string;
  timestamp?: string;
}

/**
 * Type guard for JsonMap
 */
export function isRecord(value: unknown): value is JsonMap {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Require string helper
 */
export function requireString(value: unknown, name: string): string {
  const text = value?.toString().trim() ?? "";
  if (!text) {
    throw new SafeError("INVALID_PAYLOAD", `${name} alanı zorunlu.`, 400);
  }
  return text;
}

/**
 * Require number helper
 */
export function requireNumber(value: unknown, name: string): number {
  const num = Number(value);
  if (!Number.isFinite(num)) {
    throw new SafeError("INVALID_PAYLOAD", `${name} sayı olmalı.`, 400);
  }
  return num;
}
