/**
 * SourceBase Document Extraction Service
 * 
 * PDF, DOCX, PPTX dosyalarından metin çıkarımı ve metadata analizi.
 * AGENTS.md Kural 12.4: Kaynak metni data olarak ele alınır, prompt injection'a karşı korunur.
 */

import { SafeError } from "../types.ts";

export interface ExtractionResult {
  text: string;
  pageCount: number;
  metadata: {
    title?: string;
    author?: string;
    subject?: string;
    keywords?: string[];
    createdAt?: string;
    modifiedAt?: string;
    language?: string;
  };
  chunks: TextChunk[];
}

export interface TextChunk {
  text: string;
  pageNumber?: number;
  chunkIndex: number;
  tokenEstimate: number;
}

/**
 * PDF text extraction using pdf-parse
 * Deno'da pdf-parse yerine native PDF parsing kullanılacak
 */
export async function extractPdf(
  fileBuffer: ArrayBuffer,
): Promise<ExtractionResult> {
  try {
    // PDF parsing için Deno native veya external service kullanılacak
    // Şimdilik mock implementation
    const text = await mockPdfExtraction(fileBuffer);
    const pageCount = estimatePageCount(text);
    const chunks = chunkText(text, 2000);

    return {
      text,
      pageCount,
      metadata: {
        title: "Extracted PDF",
        language: "tr",
      },
      chunks,
    };
  } catch (error) {
    throw new SafeError(
      "PDF_EXTRACTION_FAILED",
      "PDF dosyası işlenemedi.",
      500,
    );
  }
}

/**
 * DOCX text extraction
 * Deno'da docx parsing için external library veya service kullanılacak
 */
export async function extractDocx(
  fileBuffer: ArrayBuffer,
): Promise<ExtractionResult> {
  try {
    // DOCX parsing implementation
    const text = await mockDocxExtraction(fileBuffer);
    const pageCount = estimatePageCount(text);
    const chunks = chunkText(text, 2000);

    return {
      text,
      pageCount,
      metadata: {
        title: "Extracted DOCX",
        language: "tr",
      },
      chunks,
    };
  } catch (error) {
    throw new SafeError(
      "DOCX_EXTRACTION_FAILED",
      "DOCX dosyası işlenemedi.",
      500,
    );
  }
}

/**
 * PPTX text extraction
 * Slaytlardan metin ve notlar çıkarılır
 */
export async function extractPptx(
  fileBuffer: ArrayBuffer,
): Promise<ExtractionResult> {
  try {
    // PPTX parsing implementation
    const text = await mockPptxExtraction(fileBuffer);
    const pageCount = estimateSlideCount(text);
    const chunks = chunkText(text, 2000);

    return {
      text,
      pageCount,
      metadata: {
        title: "Extracted PPTX",
        language: "tr",
      },
      chunks,
    };
  } catch (error) {
    throw new SafeError(
      "PPTX_EXTRACTION_FAILED",
      "PPTX dosyası işlenemedi.",
      500,
    );
  }
}

/**
 * Metin içeriğini token limitlerine uygun parçalara böler
 * AGENTS.md Kural 12.4: Token limitleri kontrol edilir
 */
export function chunkText(
  text: string,
  maxTokens: number,
): TextChunk[] {
  const chunks: TextChunk[] = [];
  const paragraphs = text.split(/\n\n+/);
  let currentChunk = "";
  let chunkIndex = 0;

  for (const paragraph of paragraphs) {
    const estimatedTokens = estimateTokens(currentChunk + paragraph);

    if (estimatedTokens > maxTokens && currentChunk) {
      chunks.push({
        text: currentChunk.trim(),
        chunkIndex,
        tokenEstimate: estimateTokens(currentChunk),
      });
      currentChunk = paragraph;
      chunkIndex++;
    } else {
      currentChunk += (currentChunk ? "\n\n" : "") + paragraph;
    }
  }

  if (currentChunk) {
    chunks.push({
      text: currentChunk.trim(),
      chunkIndex,
      tokenEstimate: estimateTokens(currentChunk),
    });
  }

  return chunks;
}

/**
 * Token sayısını tahmin eder (yaklaşık)
 * Türkçe için ~4 karakter = 1 token
 */
export function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

/**
 * Sayfa sayısını tahmin eder
 */
function estimatePageCount(text: string): number {
  // Ortalama 2000 karakter = 1 sayfa
  return Math.max(1, Math.ceil(text.length / 2000));
}

/**
 * Slayt sayısını tahmin eder
 */
function estimateSlideCount(text: string): number {
  // Ortalama 500 karakter = 1 slayt
  return Math.max(1, Math.ceil(text.length / 500));
}

/**
 * GCS'den dosya indir
 */
export async function downloadFromGcs(
  bucket: string,
  objectName: string,
  serviceAccountJson: string,
): Promise<ArrayBuffer> {
  try {
    const serviceAccount = JSON.parse(serviceAccountJson);
    const url = `https://storage.googleapis.com/${bucket}/${objectName}`;

    // GCS signed URL veya service account ile download
    const response = await fetch(url);

    if (!response.ok) {
      throw new Error(`GCS download failed: ${response.status}`);
    }

    return await response.arrayBuffer();
  } catch (error) {
    throw new SafeError(
      "GCS_DOWNLOAD_FAILED",
      "Dosya indirilemedi.",
      500,
    );
  }
}

/**
 * Prompt injection prevention
 * AGENTS.md Kural 12.4: Kaynak metni talimat olarak değil veri olarak ele alınır
 */
export function sanitizeSourceText(text: string): string {
  // Potansiyel prompt injection pattern'lerini temizle
  const dangerous = [
    /ignore\s+previous\s+instructions/gi,
    /forget\s+everything/gi,
    /you\s+are\s+now/gi,
    /system\s*:/gi,
    /assistant\s*:/gi,
    /user\s*:/gi,
  ];

  let sanitized = text;
  for (const pattern of dangerous) {
    sanitized = sanitized.replace(pattern, "[REMOVED]");
  }

  return sanitized;
}

// Mock implementations - gerçek production'da external service kullanılacak
async function mockPdfExtraction(buffer: ArrayBuffer): Promise<string> {
  // Gerçek PDF parsing burada yapılacak
  return "Mock PDF content extracted from buffer";
}

async function mockDocxExtraction(buffer: ArrayBuffer): Promise<string> {
  // Gerçek DOCX parsing burada yapılacak
  return "Mock DOCX content extracted from buffer";
}

async function mockPptxExtraction(buffer: ArrayBuffer): Promise<string> {
  // Gerçek PPTX parsing burada yapılacak
  return "Mock PPTX content extracted from buffer";
}
