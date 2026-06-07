import { ObjectStorageConfig } from "../config.ts";
import { SafeError } from "../types.ts";

export interface ObjectMetadata {
  name: string;
  contentLength: number;
  contentType: string;
}

export async function createSignedPutUrl(input: {
  storage: ObjectStorageConfig;
  objectName: string;
  expiresInSeconds: number;
}) {
  return createS3PresignedUrl({
    storage: input.storage,
    method: "PUT",
    objectName: input.objectName,
    expiresInSeconds: input.expiresInSeconds,
  });
}

export async function createSignedReadUrl(input: {
  storage: ObjectStorageConfig;
  objectName: string;
  expiresInSeconds: number;
}) {
  return createS3PresignedUrl({
    storage: input.storage,
    method: "GET",
    objectName: input.objectName,
    expiresInSeconds: input.expiresInSeconds,
  });
}

export async function getObjectMetadata(input: {
  storage: ObjectStorageConfig;
  bucket: string;
  objectName: string;
}): Promise<ObjectMetadata> {
  const response = await fetch(
    await createS3PresignedUrl({
      storage: input.storage,
      method: "HEAD",
      objectName: input.objectName,
      expiresInSeconds: 300,
    }),
    { method: "HEAD" },
  );
  if (response.status === 404) {
    throw new SafeError(
      "FILE_OBJECT_MISSING",
      "Yüklenen dosya depolama alanında bulunamadı.",
      400,
    );
  }
  if (response.status === 401 || response.status === 403) {
    throw new SafeError(
      "STORAGE_AUTH_FAILED",
      "Dosya depolama kimlik doğrulaması başarısız.",
      500,
    );
  }
  if (!response.ok) {
    throw new SafeError(
      "UPLOAD_VERIFY_FAILED",
      "Yüklenen dosya doğrulanamadı.",
      500,
    );
  }

  const contentLength = Number(response.headers.get("content-length") ?? 0);
  if (!Number.isFinite(contentLength) || contentLength <= 0) {
    throw new SafeError(
      "FILE_OBJECT_EMPTY",
      "Yüklenen dosya boş görünüyor.",
      400,
    );
  }

  return {
    name: input.objectName,
    contentLength,
    contentType: response.headers.get("content-type")?.toLowerCase().trim() ??
      "",
  };
}

export async function deleteObject(input: {
  storage: ObjectStorageConfig;
  bucket: string;
  objectName: string;
}) {
  try {
    const response = await fetch(
      await createS3PresignedUrl({
        storage: input.storage,
        method: "DELETE",
        objectName: input.objectName,
        expiresInSeconds: 300,
      }),
      { method: "DELETE" },
    );
    if (!response.ok && response.status !== 404) {
      console.warn("S3 delete skipped:", response.status);
    }
  } catch (error) {
    const safeCode = error instanceof SafeError
      ? error.code
      : "STORAGE_DELETE_ERROR";
    console.warn("S3 delete skipped:", safeCode);
  }
}

async function createS3PresignedUrl(input: {
  storage: ObjectStorageConfig;
  method: "DELETE" | "GET" | "HEAD" | "PUT";
  objectName: string;
  expiresInSeconds: number;
}) {
  assertObjectName(input.objectName);
  const now = new Date();
  const date = now.toISOString().slice(0, 10).replaceAll("-", "");
  const timestamp = `${date}T${
    now.toISOString().slice(11, 19).replaceAll(":", "")
  }Z`;
  const scope = `${date}/${input.storage.region}/s3/aws4_request`;
  const credential = `${input.storage.accessKeyId}/${scope}`;
  const endpoint = new URL(input.storage.endpoint);
  const host = endpoint.host;
  const canonicalUri = `/${encodePath(input.storage.bucket)}/${
    encodePath(input.objectName)
  }`;
  const query: Record<string, string> = {
    "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
    "X-Amz-Credential": credential,
    "X-Amz-Date": timestamp,
    "X-Amz-Expires": String(input.expiresInSeconds),
    "X-Amz-SignedHeaders": "host",
  };
  const canonicalQuery = canonicalQueryString(query);
  const canonicalRequest = [
    input.method,
    canonicalUri,
    canonicalQuery,
    `host:${host}\n`,
    "host",
    "UNSIGNED-PAYLOAD",
  ].join("\n");
  const key = await signingKey(
    input.storage.secretAccessKey,
    date,
    input.storage.region,
  );
  const signature = await hmacHex(
    key,
    await stringToSign(timestamp, scope, canonicalRequest),
  );
  return `${endpoint.origin}${canonicalUri}?${canonicalQuery}&X-Amz-Signature=${signature}`;
}

function assertObjectName(objectName: string) {
  if (!objectName || objectName.includes("..") || objectName.startsWith("/")) {
    throw new SafeError(
      "STORAGE_OBJECT_INVALID",
      "Dosya depolama yolu geçersiz.",
      400,
    );
  }
}

async function stringToSign(
  timestamp: string,
  scope: string,
  canonicalRequest: string,
) {
  return [
    "AWS4-HMAC-SHA256",
    timestamp,
    scope,
    await sha256Hex(canonicalRequest),
  ].join("\n");
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

async function signingKey(secret: string, date: string, region: string) {
  const dateKey = await hmacBytes(textBytes(`AWS4${secret}`), date);
  const regionKey = await hmacBytes(dateKey, region);
  const serviceKey = await hmacBytes(regionKey, "s3");
  return await hmacBytes(serviceKey, "aws4_request");
}

async function hmacHex(keyBytes: Uint8Array, text: string) {
  return toHex(await hmacBytes(keyBytes, text));
}

async function hmacBytes(keyBytes: Uint8Array, text: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(text)),
  );
}

async function sha256Hex(text: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return toHex(new Uint8Array(digest));
}

function textBytes(text: string) {
  return new TextEncoder().encode(text);
}

function toHex(bytes: Uint8Array) {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
