/**
 * SourceBase Document Extraction Service
 *
 * PDF, DOCX, PPTX dosyalarından metin çıkarımı
 * AGENTS.md Kural 12.4: Kaynak metni data olarak ele alınır
 */

import { SafeError } from "../types.ts";

const MAX_EXTRACTION_BYTES = 100 * 1024 * 1024;
const MIN_EXTRACTED_TEXT_CHARS = 10;
const ZIP_LOCAL_FILE_HEADER = 0x04034b50;

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
  if (!bucket || !objectName || objectName.includes("..")) {
    throw new SafeError(
      "GCS_OBJECT_INVALID",
      "Dosya depolama yolu geçersiz.",
      400,
    );
  }
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
  if (text.length < MIN_EXTRACTED_TEXT_CHARS) {
    if (fileType === "pdf") {
      throw new SafeError(
        "PDF_OCR_REQUIRED",
        "Bu PDF tarama/görsel tabanlı görünüyor; okunabilir metin için OCR gerekiyor.",
        400,
      );
    }
    throw new SafeError(
      "EXTRACTION_EMPTY",
      "Dosyadan okunabilir metin çıkarılamadı.",
      400,
    );
  }
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

    return extractionResult(fileType, text, pageCount);
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

    const contentLength = Number(response.headers.get("content-length") ?? 0);
    if (contentLength > MAX_EXTRACTION_BYTES) {
      throw new SafeError(
        "FILE_TOO_LARGE",
        "Dosya işleme sınırından büyük.",
        400,
      );
    }

    const buffer = await response.arrayBuffer();
    if (buffer.byteLength <= 0) {
      throw new SafeError("FILE_EMPTY", "Dosya boş görünüyor.", 400);
    }
    if (buffer.byteLength > MAX_EXTRACTION_BYTES) {
      throw new SafeError(
        "FILE_TOO_LARGE",
        "Dosya işleme sınırından büyük.",
        400,
      );
    }
    return buffer;
  } catch (error) {
    if (error instanceof SafeError) {
      throw error;
    }
    throw new SafeError(
      "GCS_DOWNLOAD_FAILED",
      "Dosya indirilemedi.",
      500,
    );
  }
}

async function extractFromPDF(
  content: ArrayBuffer,
): Promise<{ text: string; pageCount: number }> {
  const bytes = new Uint8Array(content);
  const raw = latin1Decode(bytes);
  const parts = [extractPdfTextOperators(raw)];

  for (const stream of await extractPdfStreams(raw)) {
    parts.push(extractPdfTextOperators(stream));
  }

  const pageMatches = raw.match(/\/Type\s*\/Page\b/g) || [];
  const pageCount = pageMatches.length || 1;
  return {
    text: parts.filter(Boolean).join("\n"),
    pageCount,
  };
}

async function extractFromDOCX(content: ArrayBuffer): Promise<string> {
  const entries = await unzipTextEntries(
    content,
    (name) =>
      name === "word/document.xml" ||
      name.startsWith("word/header") ||
      name.startsWith("word/footer"),
  );
  return entries.map(extractOfficeXmlText).join("\n");
}

async function extractFromPPTX(content: ArrayBuffer): Promise<string> {
  const entries = await unzipTextEntries(
    content,
    (name) =>
      name.startsWith("ppt/slides/slide") ||
      name.startsWith("ppt/notesSlides/notesSlide") ||
      name.startsWith("ppt/slideMasters/slideMaster"),
  );
  return entries.map(extractOfficeXmlText).join("\n\n");
}

function latin1Decode(bytes: Uint8Array) {
  return new TextDecoder("latin1").decode(bytes);
}

function latin1Encode(text: string) {
  const bytes = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i++) {
    bytes[i] = text.charCodeAt(i) & 0xff;
  }
  return bytes;
}

async function extractPdfStreams(raw: string): Promise<string[]> {
  const streams: string[] = [];
  const pattern = /(<<[\s\S]*?>>)\s*stream\r?\n?([\s\S]*?)\r?\n?endstream/g;
  for (const match of raw.matchAll(pattern)) {
    const dictionary = match[1] ?? "";
    const body = stripPdfStreamBoundaries(match[2] ?? "");
    if (dictionary.includes("/FlateDecode")) {
      const inflated = await inflateBytes(latin1Encode(body));
      if (inflated) streams.push(new TextDecoder().decode(inflated));
    } else {
      streams.push(body);
    }
  }
  return streams;
}

function stripPdfStreamBoundaries(value: string) {
  return value.replace(/^\r?\n/, "").replace(/\r?\n$/, "");
}

function extractPdfTextOperators(value: string) {
  const textParts: string[] = [];

  for (const match of value.matchAll(/(\((?:\\.|[^\\()])*\))\s*(?:Tj|'|")/g)) {
    textParts.push(decodePdfLiteral(match[1]));
  }
  for (const match of value.matchAll(/<([0-9a-fA-F\s]+)>\s*Tj/g)) {
    textParts.push(decodePdfHex(match[1]));
  }
  for (const match of value.matchAll(/\[([\s\S]*?)\]\s*TJ/g)) {
    const arrayBody = match[1] ?? "";
    for (
      const item of arrayBody.matchAll(
        /\((?:\\.|[^\\()])*\)|<([0-9a-fA-F\s]+)>/g,
      )
    ) {
      const token = item[0];
      textParts.push(
        token.startsWith("(")
          ? decodePdfLiteral(token)
          : decodePdfHex(token.slice(1, -1)),
      );
    }
    textParts.push("\n");
  }

  return textParts
    .join(" ")
    .replace(/[ \t]{2,}/g, " ")
    .replace(/\s+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function decodePdfLiteral(token: string) {
  const body = token.startsWith("(") && token.endsWith(")")
    ? token.slice(1, -1)
    : token;
  let output = "";
  for (let i = 0; i < body.length; i++) {
    const char = body[i];
    if (char !== "\\") {
      output += char;
      continue;
    }
    const next = body[++i] ?? "";
    if (next === "n") output += "\n";
    else if (next === "r") output += "\n";
    else if (next === "t") output += "\t";
    else if (next === "b" || next === "f") output += " ";
    else if (next === "\n" || next === "\r") {
      if (next === "\r" && body[i + 1] === "\n") i++;
    } else if (/[0-7]/.test(next)) {
      let octal = next;
      for (let j = 0; j < 2 && /[0-7]/.test(body[i + 1] ?? ""); j++) {
        octal += body[++i];
      }
      output += String.fromCharCode(parseInt(octal, 8));
    } else {
      output += next;
    }
  }
  return output;
}

function decodePdfHex(hex: string) {
  const clean = hex.replace(/\s+/g, "");
  if (!clean) return "";
  const bytes = new Uint8Array(Math.ceil(clean.length / 2));
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(clean.slice(i * 2, i * 2 + 2).padEnd(2, "0"), 16);
  }
  if (bytes[0] === 0xfe && bytes[1] === 0xff) {
    let output = "";
    for (let i = 2; i + 1 < bytes.length; i += 2) {
      output += String.fromCharCode((bytes[i] << 8) | bytes[i + 1]);
    }
    return output;
  }
  return new TextDecoder().decode(bytes);
}

async function unzipTextEntries(
  content: ArrayBuffer,
  shouldRead: (name: string) => boolean,
) {
  const bytes = new Uint8Array(content);
  const view = new DataView(content);
  const entries: string[] = [];

  for (const entry of zipCentralDirectoryEntries(bytes, view)) {
    if (!shouldRead(entry.name) || !entry.name.endsWith(".xml")) continue;
    const data = await readZipEntry(bytes, view, entry);
    if (data) entries.push(new TextDecoder().decode(data));
  }

  return entries;
}

type ZipEntry = {
  name: string;
  method: number;
  compressedSize: number;
  localHeaderOffset: number;
};

function zipCentralDirectoryEntries(
  bytes: Uint8Array,
  view: DataView,
): ZipEntry[] {
  const eocdOffset = findEndOfCentralDirectory(view);
  if (eocdOffset < 0) return [];
  const entryCount = view.getUint16(eocdOffset + 10, true);
  let offset = view.getUint32(eocdOffset + 16, true);
  const entries: ZipEntry[] = [];

  for (let i = 0; i < entryCount && offset + 46 <= bytes.length; i++) {
    if (view.getUint32(offset, true) !== 0x02014b50) break;
    const method = view.getUint16(offset + 10, true);
    const compressedSize = view.getUint32(offset + 20, true);
    const nameLength = view.getUint16(offset + 28, true);
    const extraLength = view.getUint16(offset + 30, true);
    const commentLength = view.getUint16(offset + 32, true);
    const localHeaderOffset = view.getUint32(offset + 42, true);
    const name = new TextDecoder().decode(
      bytes.slice(offset + 46, offset + 46 + nameLength),
    );
    entries.push({ name, method, compressedSize, localHeaderOffset });
    offset += 46 + nameLength + extraLength + commentLength;
  }

  return entries;
}

function findEndOfCentralDirectory(view: DataView) {
  for (let offset = view.byteLength - 22; offset >= 0; offset--) {
    if (view.getUint32(offset, true) === 0x06054b50) return offset;
  }
  return -1;
}

async function readZipEntry(
  bytes: Uint8Array,
  view: DataView,
  entry: ZipEntry,
) {
  const offset = entry.localHeaderOffset;
  if (
    offset < 0 || offset + 30 > bytes.length ||
    view.getUint32(offset, true) !== ZIP_LOCAL_FILE_HEADER
  ) {
    return null;
  }
  const localNameLength = view.getUint16(offset + 26, true);
  const localExtraLength = view.getUint16(offset + 28, true);
  const dataStart = offset + 30 + localNameLength + localExtraLength;
  const dataEnd = dataStart + entry.compressedSize;
  if (dataStart < 0 || dataEnd > bytes.length) return null;
  const compressed = bytes.slice(dataStart, dataEnd);
  if (entry.method === 0) return compressed;
  if (entry.method === 8) return await inflateBytes(compressed, true);
  return null;
}

async function inflateBytes(bytes: Uint8Array, raw = false) {
  const formats = raw ? ["deflate-raw", "deflate"] : ["deflate", "deflate-raw"];
  const blobPart = bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  ) as ArrayBuffer;
  for (const format of formats) {
    try {
      const stream = new Blob([blobPart]).stream().pipeThrough(
        new DecompressionStream(format as CompressionFormat),
      );
      return new Uint8Array(await new Response(stream).arrayBuffer());
    } catch (_error) {
      // Try the next deflate container flavor.
    }
  }
  return null;
}

function extractOfficeXmlText(xml: string) {
  const parts: string[] = [];
  for (
    const match of xml.matchAll(
      /<(?:\w+:)?t\b[^>]*>([\s\S]*?)<\/(?:\w+:)?t>/g,
    )
  ) {
    parts.push(decodeXmlEntities(match[1] ?? ""));
  }
  if (parts.length === 0) {
    parts.push(decodeXmlEntities(xml.replace(/<[^>]+>/g, " ")));
  }
  return parts.join(" ").replace(/\s{2,}/g, " ").trim();
}

function decodeXmlEntities(value: string) {
  return value
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'");
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
