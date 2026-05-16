/**
 * SourceBase Document Extraction Service
 *
 * PDF, DOCX, PPTX dosyalarından metin çıkarımı
 * AGENTS.md Kural 12.4: Kaynak metni data olarak ele alınır
 */

import { SafeError } from "../types.ts";

export interface ExtractionResult {
  text: string;
  pageCount?: number;
  chunks?: string[];
  metadata: {
    fileType: string;
    extractedAt: string;
    charCount: number;
    wordCount: number;
  };
}

export async function downloadFromGcs(
  bucket: string,
  objectName: string,
  serviceAccountJson: string,
): Promise<ArrayBuffer> {
  return downloadFile(
    await createGcsV4SignedGetUrl({
      bucket,
      objectName,
      serviceAccountJson,
      expiresInSeconds: 300,
    }),
  );
}

export async function extractPdf(
  content: ArrayBuffer,
): Promise<ExtractionResult & { chunks: string[] }> {
  const extracted = await extractFromPDF(content);
  return extractionResult("pdf", extracted.text, extracted.pageCount);
}

export async function extractDocx(
  content: ArrayBuffer,
): Promise<ExtractionResult & { chunks: string[] }> {
  return extractionResult("docx", await extractFromDOCX(content));
}

export async function extractPptx(
  content: ArrayBuffer,
): Promise<ExtractionResult & { chunks: string[] }> {
  return extractionResult("pptx", await extractFromPPTX(content));
}

function extractionResult(
  fileType: string,
  rawText: string,
  pageCount?: number,
): ExtractionResult & { chunks: string[] } {
  const text = sanitizeSourceText(rawText);
  return {
    text,
    pageCount,
    chunks: chunkText(text),
    metadata: {
      fileType,
      extractedAt: new Date().toISOString(),
      charCount: text.length,
      wordCount: text.split(/\s+/).filter((word) => word.length > 0).length,
    },
  };
}

/**
 * Dosyadan metin çıkar
 */
export async function extractText(
  fileUrl: string,
  fileType: string,
): Promise<ExtractionResult> {
  try {
    const content = await downloadFile(fileUrl);

    let text = "";
    let pageCount: number | undefined;

    switch (fileType.toLowerCase()) {
      case "pdf":
        ({ text, pageCount } = await extractFromPDF(content));
        break;
      case "docx":
        text = await extractFromDOCX(content);
        break;
      case "pptx":
        text = await extractFromPPTX(content);
        break;
      default:
        throw new SafeError(
          "UNSUPPORTED_FILE_TYPE",
          "Desteklenmeyen dosya tipi.",
          400,
        );
    }

    // Metni temizle ve sanitize et
    text = sanitizeSourceText(text);

    return {
      text,
      pageCount,
      metadata: {
        fileType,
        extractedAt: new Date().toISOString(),
        charCount: text.length,
        wordCount: text.split(/\s+/).filter((w) => w.length > 0).length,
      },
    };
  } catch (error) {
    if (error instanceof SafeError) {
      throw error;
    }
    throw new SafeError(
      "EXTRACTION_FAILED",
      "Dosyadan metin çıkarılamadı.",
      500,
    );
  }
}

/**
 * GCS'den dosya indir
 */
async function downloadFile(url: string): Promise<ArrayBuffer> {
  try {
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
 * PDF'den metin çıkar (basit implementasyon)
 */
async function extractFromPDF(
  content: ArrayBuffer,
): Promise<{ text: string; pageCount: number }> {
  // Bu basit bir implementasyon - production'da pdf-parse veya benzeri kullanılmalı
  const text = new TextDecoder().decode(content);

  // PDF'den basit metin çıkarımı
  const matches = text.match(/\/Contents\s*\(([^)]+)\)/g) || [];
  const extractedText = matches
    .map((m) => m.replace(/\/Contents\s*\(([^)]+)\)/, "$1"))
    .join("\n");

  // Sayfa sayısını tahmin et
  const pageMatches = text.match(/\/Type\s*\/Page[^s]/g) || [];
  const pageCount = pageMatches.length || 1;

  return {
    text: extractedText ||
      "PDF içeriği çıkarılamadı. Lütfen farklı bir format deneyin.",
    pageCount,
  };
}

/**
 * DOCX'den metin çıkar (basit implementasyon)
 */
async function extractFromDOCX(content: ArrayBuffer): Promise<string> {
  // Bu basit bir implementasyon - production'da mammoth veya benzeri kullanılmalı
  const text = new TextDecoder().decode(content);

  // XML içeriğinden metin çıkar
  const matches = text.match(/<w:t[^>]*>([^<]+)<\/w:t>/g) || [];
  const extractedText = matches
    .map((m) => m.replace(/<w:t[^>]*>([^<]+)<\/w:t>/, "$1"))
    .join(" ");

  return extractedText ||
    "DOCX içeriği çıkarılamadı. Lütfen farklı bir format deneyin.";
}

/**
 * PPTX'den metin çıkar (basit implementasyon)
 */
async function extractFromPPTX(content: ArrayBuffer): Promise<string> {
  // Bu basit bir implementasyon - production'da pptx-parser veya benzeri kullanılmalı
  const text = new TextDecoder().decode(content);

  // XML içeriğinden metin çıkar
  const matches = text.match(/<a:t[^>]*>([^<]+)<\/a:t>/g) || [];
  const extractedText = matches
    .map((m) => m.replace(/<a:t[^>]*>([^<]+)<\/a:t>/, "$1"))
    .join("\n");

  return extractedText ||
    "PPTX içeriği çıkarılamadı. Lütfen farklı bir format deneyin.";
}

/**
 * Kaynak metnini temizle ve sanitize et
 * AGENTS.md Kural 12.4: Prompt injection'a karşı koruma
 */
export function sanitizeSourceText(text: string): string {
  return text
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "") // Kontrol karakterlerini kaldır
    .replace(/\r\n/g, "\n") // Windows line endings'i normalize et
    .replace(/\r/g, "\n") // Mac line endings'i normalize et
    .replace(/\n{3,}/g, "\n\n") // Fazla boş satırları temizle
    .trim();
}

/**
 * Metni token limitine göre chunk'la
 */
export function chunkText(text: string, maxTokens = 8000): string[] {
  // Basit karakter bazlı chunking (1 token ≈ 4 karakter)
  const maxChars = maxTokens * 4;
  const chunks: string[] = [];

  let currentChunk = "";
  const paragraphs = text.split("\n\n");

  for (const paragraph of paragraphs) {
    if ((currentChunk + paragraph).length > maxChars) {
      if (currentChunk) {
        chunks.push(currentChunk.trim());
        currentChunk = "";
      }

      // Eğer tek paragraf çok büyükse, zorla böl
      if (paragraph.length > maxChars) {
        const words = paragraph.split(" ");
        for (const word of words) {
          if ((currentChunk + " " + word).length > maxChars) {
            chunks.push(currentChunk.trim());
            currentChunk = word;
          } else {
            currentChunk += (currentChunk ? " " : "") + word;
          }
        }
      } else {
        currentChunk = paragraph;
      }
    } else {
      currentChunk += (currentChunk ? "\n\n" : "") + paragraph;
    }
  }

  if (currentChunk) {
    chunks.push(currentChunk.trim());
  }

  return chunks;
}

/**
 * Token sayısını tahmin et
 */
export function estimateTokens(text: string): number {
  // Basit tahmin: 1 token ≈ 4 karakter
  return Math.ceil(text.length / 4);
}

async function createGcsV4SignedGetUrl(input: {
  bucket: string;
  objectName: string;
  serviceAccountJson: string;
  expiresInSeconds: number;
}) {
  const serviceAccount = JSON.parse(input.serviceAccountJson);
  const clientEmail = String(serviceAccount.client_email ?? "");
  const privateKey = String(serviceAccount.private_key ?? "");
  if (!clientEmail || !privateKey) {
    throw new SafeError(
      "GCS_SERVICE_ACCOUNT_INVALID",
      "GCS service JSON geçersiz.",
      500,
    );
  }

  const now = new Date();
  const date = formatDate(now);
  const timestamp = `${date}T${formatTime(now)}Z`;
  const scope = `${date}/auto/storage/goog4_request`;
  const credential = `${clientEmail}/${scope}`;
  const canonicalUri = `/${encodePath(input.bucket)}/${
    encodePath(input.objectName)
  }`;
  const query: Record<string, string> = {
    "X-Goog-Algorithm": "GOOG4-RSA-SHA256",
    "X-Goog-Credential": credential,
    "X-Goog-Date": timestamp,
    "X-Goog-Expires": String(input.expiresInSeconds),
    "X-Goog-SignedHeaders": "host",
  };
  const canonicalQuery = canonicalQueryString(query);
  const canonicalRequest = [
    "GET",
    canonicalUri,
    canonicalQuery,
    "host:storage.googleapis.com\n",
    "host",
    "UNSIGNED-PAYLOAD",
  ].join("\n");
  const stringToSign = [
    "GOOG4-RSA-SHA256",
    timestamp,
    scope,
    await sha256Hex(canonicalRequest),
  ].join("\n");
  const signature = await rsaSha256(privateKey, stringToSign);
  return `https://storage.googleapis.com${canonicalUri}?${canonicalQuery}&X-Goog-Signature=${signature}`;
}

function encodePath(path: string) {
  return path.split("/").map(rfc3986Encode).join("/");
}

function canonicalQueryString(query: Record<string, string>) {
  return Object.entries(query)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${rfc3986Encode(key)}=${rfc3986Encode(value)}`)
    .join("&");
}

function rfc3986Encode(value: string) {
  return encodeURIComponent(value).replace(
    /[!'()*]/g,
    (char) => `%${char.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return toHex(new Uint8Array(digest));
}

async function rsaSha256(privateKeyPem: string, value: string) {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKeyPem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(value),
  );
  return toHex(new Uint8Array(signature));
}

function pemToArrayBuffer(pem: string) {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function toHex(bytes: Uint8Array) {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function formatDate(date: Date) {
  return date.toISOString().slice(0, 10).replaceAll("-", "");
}

function formatTime(date: Date) {
  return date.toISOString().slice(11, 19).replaceAll(":", "");
}
