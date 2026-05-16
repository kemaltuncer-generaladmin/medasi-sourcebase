/**
 * SourceBase Type Definitions
 * Tüm Edge Function'lar için ortak tipler
 */

export class SafeError extends Error {
  constructor(
    public code: string,
    message: string,
    public status: number = 400,
  ) {
    super(message);
    this.name = "SafeError";
  }
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function requireString(value: unknown, name: string): string {
  const text = value?.toString().trim() ?? "";
  if (!text) {
    throw new SafeError("INVALID_PAYLOAD", `${name} alanı zorunlu.`, 400);
  }
  return text;
}

// Job Status Types
export type JobStatus =
  | "queued"
  | "processing"
  | "completed"
  | "failed"
  | "cancelled";

// Generation Types
export type GenerationType =
  | "flashcard"
  | "quiz"
  | "summary"
  | "algorithm"
  | "comparison"
  | "podcast";

// AI Provider Types
export type AIProvider = "vertex" | "openai";

// Generation Job Interface
export interface GenerationJob {
  id: string;
  owner_user_id: string;
  source_file_id?: string;
  source_id?: string;
  deck_id?: string;
  job_type: GenerationType;
  status: JobStatus;
  model?: string;
  input_tokens?: number;
  output_tokens?: number;
  cost_estimate?: number;
  error_message?: string;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

// Flashcard Interface
export interface Flashcard {
  front: string;
  back: string;
  explanation?: string;
  tags?: string[];
  difficulty?: "easy" | "medium" | "hard";
}

// Quiz Question Interface
export interface QuizQuestion {
  question: string;
  options: string[];
  correctIndex: number;
  explanation: string;
  difficulty?: "easy" | "medium" | "hard";
}

// Summary Interface
export interface Summary {
  title: string;
  bulletPoints: string[];
  fullText: string;
}

// Algorithm Interface
export interface Algorithm {
  title: string;
  steps: Array<{
    stepNumber: number;
    title: string;
    description: string;
  }>;
  notes?: string;
}

// Comparison Table Interface
export interface ComparisonTable {
  title: string;
  headers: string[];
  rows: Array<{
    label: string;
    values: string[];
  }>;
}

// Podcast Script Interface
export interface PodcastScript {
  title: string;
  duration: string;
  segments: Array<{
    speaker: string;
    text: string;
    timestamp?: string;
  }>;
}

// Central AI Chat Message
export interface ChatMessage {
  role: "user" | "assistant" | "system";
  content: string;
  timestamp?: string;
}

// Central AI Chat Response
export interface ChatResponse {
  message: string;
  suggestions?: string[];
  context?: Record<string, unknown>;
}
