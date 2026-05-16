/**
 * SourceBase Content Validators
 * 
 * AI üretilen içeriklerin schema validation ve quality checks.
 * AGENTS.md Kural 12.4: Output quality checks ve schema validation
 */

import {
  Algorithm,
  AlgorithmStep,
  ComparisonRow,
  ComparisonTable,
  Flashcard,
  PodcastScript,
  PodcastSegment,
  QuizQuestion,
  SafeError,
  Summary,
} from "../types.ts";

/**
 * Validation result
 */
export interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
}

/**
 * Flashcard validator
 * AGENTS.md Kural 12.3: Kart kalite kuralları
 */
export function validateFlashcard(card: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isRecord(card)) {
    errors.push("Flashcard bir obje olmalı");
    return { valid: false, errors, warnings };
  }

  // Front validation
  if (!card.front || typeof card.front !== "string") {
    errors.push("front alanı zorunlu ve string olmalı");
  } else {
    if (card.front.length < 5) {
      errors.push("front çok kısa (min 5 karakter)");
    }
    if (card.front.length > 500) {
      warnings.push("front çok uzun (max 500 karakter önerilir)");
    }
    // Birden fazla soru işareti kontrolü
    if ((card.front.match(/\?/g) || []).length > 2) {
      warnings.push("front birden fazla soru içeriyor olabilir");
    }
  }

  // Back validation
  if (!card.back || typeof card.back !== "string") {
    errors.push("back alanı zorunlu ve string olmalı");
  } else {
    if (card.back.length < 2) {
      errors.push("back çok kısa (min 2 karakter)");
    }
    if (card.back.length > 1000) {
      warnings.push("back çok uzun (max 1000 karakter önerilir)");
    }
  }

  // Explanation validation (optional)
  if (card.explanation && typeof card.explanation !== "string") {
    errors.push("explanation string olmalı");
  }

  // Difficulty validation (optional)
  if (card.difficulty) {
    const validDifficulties = ["easy", "medium", "hard"];
    if (!validDifficulties.includes(String(card.difficulty))) {
      errors.push("difficulty easy, medium veya hard olmalı");
    }
  }

  // Tags validation (optional)
  if (card.tags) {
    if (!Array.isArray(card.tags)) {
      errors.push("tags array olmalı");
    } else if (!card.tags.every((t) => typeof t === "string")) {
      errors.push("tags string array olmalı");
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Flashcard array validator
 */
export function validateFlashcards(cards: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!Array.isArray(cards)) {
    errors.push("Flashcards array olmalı");
    return { valid: false, errors, warnings };
  }

  if (cards.length === 0) {
    errors.push("En az 1 flashcard olmalı");
    return { valid: false, errors, warnings };
  }

  if (cards.length > 200) {
    warnings.push("Çok fazla flashcard (max 200 önerilir)");
  }

  // Her kartı validate et
  cards.forEach((card, index) => {
    const result = validateFlashcard(card);
    if (!result.valid) {
      errors.push(`Kart ${index + 1}: ${result.errors.join(", ")}`);
    }
    warnings.push(...result.warnings.map((w) => `Kart ${index + 1}: ${w}`));
  });

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Quiz question validator
 */
export function validateQuizQuestion(question: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isRecord(question)) {
    errors.push("Quiz question bir obje olmalı");
    return { valid: false, errors, warnings };
  }

  // Question validation
  if (!question.question || typeof question.question !== "string") {
    errors.push("question alanı zorunlu ve string olmalı");
  } else {
    if (question.question.length < 10) {
      errors.push("question çok kısa (min 10 karakter)");
    }
    if (question.question.length > 500) {
      warnings.push("question çok uzun (max 500 karakter önerilir)");
    }
  }

  // Options validation
  if (!Array.isArray(question.options)) {
    errors.push("options array olmalı");
  } else {
    if (question.options.length < 2) {
      errors.push("En az 2 seçenek olmalı");
    }
    if (question.options.length > 6) {
      warnings.push("Çok fazla seçenek (max 6 önerilir)");
    }
    if (!question.options.every((o) => typeof o === "string")) {
      errors.push("options string array olmalı");
    }
    // Boş seçenek kontrolü
    if (question.options.some((o: unknown) => !String(o).trim())) {
      errors.push("Boş seçenek olamaz");
    }
  }

  // CorrectIndex validation
  if (typeof question.correctIndex !== "number") {
    errors.push("correctIndex number olmalı");
  } else {
    if (
      !Number.isInteger(question.correctIndex) || question.correctIndex < 0
    ) {
      errors.push("correctIndex geçerli bir index olmalı");
    }
    if (
      Array.isArray(question.options) &&
      question.correctIndex >= question.options.length
    ) {
      errors.push("correctIndex options array sınırları içinde olmalı");
    }
  }

  // Explanation validation
  if (!question.explanation || typeof question.explanation !== "string") {
    errors.push("explanation alanı zorunlu ve string olmalı");
  } else {
    if (question.explanation.length < 10) {
      warnings.push("explanation çok kısa (min 10 karakter önerilir)");
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Quiz array validator
 */
export function validateQuiz(questions: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!Array.isArray(questions)) {
    errors.push("Quiz questions array olmalı");
    return { valid: false, errors, warnings };
  }

  if (questions.length === 0) {
    errors.push("En az 1 soru olmalı");
    return { valid: false, errors, warnings };
  }

  questions.forEach((question, index) => {
    const result = validateQuizQuestion(question);
    if (!result.valid) {
      errors.push(`Soru ${index + 1}: ${result.errors.join(", ")}`);
    }
    warnings.push(...result.warnings.map((w) => `Soru ${index + 1}: ${w}`));
  });

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Summary validator
 */
export function validateSummary(summary: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isRecord(summary)) {
    errors.push("Summary bir obje olmalı");
    return { valid: false, errors, warnings };
  }

  // BulletPoints validation
  if (!Array.isArray(summary.bulletPoints)) {
    errors.push("bulletPoints array olmalı");
  } else {
    if (summary.bulletPoints.length === 0) {
      errors.push("En az 1 madde olmalı");
    }
    if (!summary.bulletPoints.every((b) => typeof b === "string")) {
      errors.push("bulletPoints string array olmalı");
    }
  }

  // FullText validation
  if (!summary.fullText || typeof summary.fullText !== "string") {
    errors.push("fullText alanı zorunlu ve string olmalı");
  } else {
    if (summary.fullText.length < 50) {
      warnings.push("fullText çok kısa (min 50 karakter önerilir)");
    }
  }

  // KeyTerms validation (optional)
  if (summary.keyTerms) {
    if (!Array.isArray(summary.keyTerms)) {
      errors.push("keyTerms array olmalı");
    } else if (!summary.keyTerms.every((t) => typeof t === "string")) {
      errors.push("keyTerms string array olmalı");
    }
  }

  // MainTopics validation (optional)
  if (summary.mainTopics) {
    if (!Array.isArray(summary.mainTopics)) {
      errors.push("mainTopics array olmalı");
    } else if (!summary.mainTopics.every((t) => typeof t === "string")) {
      errors.push("mainTopics string array olmalı");
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Algorithm validator
 */
export function validateAlgorithm(algorithm: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isRecord(algorithm)) {
    errors.push("Algorithm bir obje olmalı");
    return { valid: false, errors, warnings };
  }

  // Title validation
  if (!algorithm.title || typeof algorithm.title !== "string") {
    errors.push("title alanı zorunlu ve string olmalı");
  }

  // Steps validation
  if (!Array.isArray(algorithm.steps)) {
    errors.push("steps array olmalı");
  } else {
    if (algorithm.steps.length === 0) {
      errors.push("En az 1 adım olmalı");
    }

    algorithm.steps.forEach((step, index) => {
      if (!isRecord(step)) {
        errors.push(`Adım ${index + 1}: obje olmalı`);
        return;
      }

      if (typeof step.stepNumber !== "number") {
        errors.push(`Adım ${index + 1}: stepNumber number olmalı`);
      }

      if (!step.title || typeof step.title !== "string") {
        errors.push(`Adım ${index + 1}: title zorunlu ve string olmalı`);
      }

      if (!step.description || typeof step.description !== "string") {
        errors.push(`Adım ${index + 1}: description zorunlu ve string olmalı`);
      }

      if (step.substeps) {
        if (!Array.isArray(step.substeps)) {
          errors.push(`Adım ${index + 1}: substeps array olmalı`);
        } else if (!step.substeps.every((s) => typeof s === "string")) {
          errors.push(`Adım ${index + 1}: substeps string array olmalı`);
        }
      }
    });
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Comparison table validator
 */
export function validateComparisonTable(
  table: unknown,
): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isRecord(table)) {
    errors.push("Comparison table bir obje olmalı");
    return { valid: false, errors, warnings };
  }

  // Title validation
  if (!table.title || typeof table.title !== "string") {
    errors.push("title alanı zorunlu ve string olmalı");
  }

  // Headers validation
  if (!Array.isArray(table.headers)) {
    errors.push("headers array olmalı");
  } else {
    if (table.headers.length < 2) {
      errors.push("En az 2 header olmalı");
    }
    if (!table.headers.every((h) => typeof h === "string")) {
      errors.push("headers string array olmalı");
    }
  }

  // Rows validation
  if (!Array.isArray(table.rows)) {
    errors.push("rows array olmalı");
  } else {
    if (table.rows.length === 0) {
      errors.push("En az 1 satır olmalı");
    }

    table.rows.forEach((row, index) => {
      if (!isRecord(row)) {
        errors.push(`Satır ${index + 1}: obje olmalı`);
        return;
      }

      if (!row.label || typeof row.label !== "string") {
        errors.push(`Satır ${index + 1}: label zorunlu ve string olmalı`);
      }

      if (!Array.isArray(row.values)) {
        errors.push(`Satır ${index + 1}: values array olmalı`);
      } else {
        if (!row.values.every((v) => typeof v === "string")) {
          errors.push(`Satır ${index + 1}: values string array olmalı`);
        }
        // Header sayısı ile values sayısı eşleşmeli
        if (
          Array.isArray(table.headers) &&
          row.values.length !== table.headers.length - 1
        ) {
          warnings.push(
            `Satır ${index + 1}: values sayısı header sayısı ile eşleşmiyor`,
          );
        }
      }
    });
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Podcast script validator
 */
export function validatePodcastScript(script: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isRecord(script)) {
    errors.push("Podcast script bir obje olmalı");
    return { valid: false, errors, warnings };
  }

  // Title validation
  if (!script.title || typeof script.title !== "string") {
    errors.push("title alanı zorunlu ve string olmalı");
  }

  // Duration validation
  if (!script.duration || typeof script.duration !== "string") {
    errors.push("duration alanı zorunlu ve string olmalı");
  }

  // Segments validation
  if (!Array.isArray(script.segments)) {
    errors.push("segments array olmalı");
  } else {
    if (script.segments.length === 0) {
      errors.push("En az 1 segment olmalı");
    }

    script.segments.forEach((segment, index) => {
      if (!isRecord(segment)) {
        errors.push(`Segment ${index + 1}: obje olmalı`);
        return;
      }

      const validSpeakers = ["host", "expert"];
      if (!validSpeakers.includes(String(segment.speaker))) {
        errors.push(`Segment ${index + 1}: speaker host veya expert olmalı`);
      }

      if (!segment.text || typeof segment.text !== "string") {
        errors.push(`Segment ${index + 1}: text zorunlu ve string olmalı`);
      } else {
        if (segment.text.length < 10) {
          warnings.push(`Segment ${index + 1}: text çok kısa`);
        }
      }
    });
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Type guard helper
 */
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Validate and throw if invalid
 */
export function assertValid(
  result: ValidationResult,
  contentType: string,
): void {
  if (!result.valid) {
    throw new SafeError(
      "INVALID_CONTENT",
      `${contentType} validation failed: ${result.errors.join(", ")}`,
      400,
    );
  }
}
