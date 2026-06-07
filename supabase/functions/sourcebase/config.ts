import { isRecord, SafeError } from "./types.ts";

export interface GoogleServiceAccount {
  clientEmail: string;
  privateKey: string;
  projectId?: string;
}

export interface ObjectStorageConfig {
  provider: "s3";
  bucket: string;
  endpoint: string;
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
}

export interface VertexConfig {
  supabaseUrl: string;
  serviceRoleKey: string;
  vertexProjectId: string;
  vertexLocation: string;
  vertexModel: string;
  vertexServiceAccountJson: string;
  serviceAccount: GoogleServiceAccount;
}

export function envValue(...names: string[]) {
  return firstEnv(...names);
}

export function getSupabaseUrl() {
  return envValue("SUPABASE_URL", "SOURCEBASE_SUPABASE_URL");
}

export function getSupabaseAnonKey() {
  return envValue(
    "SUPABASE_ANON_KEY",
    "SOURCEBASE_SUPABASE_PUBLIC_TOKEN",
    "SOURCEBASE_SUPABASE_ANON_KEY",
  );
}

export function getSupabaseServiceRoleKey() {
  return envValue(
    "SUPABASE_SERVICE_ROLE_KEY",
    "SOURCEBASE_SUPABASE_SERVICE_ROLE_KEY",
    "SUPABASE_SERVICE_KEY",
  );
}

export function getAllowedOrigin() {
  return envValue("SOURCEBASE_ALLOWED_ORIGIN", "SOURCEBASE_PUBLIC_URL") ||
    "https://sourcebase.medasi.com.tr";
}

export function getClientExtractionEnabled(): boolean {
  const value = envValue(
    "CLIENT_EXTRACTION_ENABLED",
    "SOURCEBASE_CLIENT_EXTRACTION_ENABLED",
  ).toLowerCase();
  if (!value) return true;
  return value !== "false" && value !== "0" && value !== "off";
}

export function getObjectStorageConfig(): ObjectStorageConfig {
  const driver = envValue("STORAGE_DRIVER", "SOURCEBASE_STORAGE_DRIVER")
    .toLowerCase();
  const bucket = canonicalFirst("S3_BUCKET", "SOURCEBASE_S3_BUCKET") ||
    "medasistorage";
  const endpoint = canonicalFirst("S3_ENDPOINT", "SOURCEBASE_S3_ENDPOINT") ||
    "https://storage.medasi.com.tr";
  const accessKeyId = canonicalFirst(
    "S3_ACCESS_KEY",
    "S3_ACCESS_KEY_ID",
    "SOURCEBASE_S3_ACCESS_KEY",
    "SOURCEBASE_S3_ACCESS_KEY_ID",
  );
  const secretAccessKey = canonicalFirst(
    "S3_SECRET_KEY",
    "S3_SECRET_ACCESS_KEY",
    "SOURCEBASE_S3_SECRET_KEY",
    "SOURCEBASE_S3_SECRET_ACCESS_KEY",
  );
  if (driver && driver !== "s3") {
    throw new SafeError(
      "S3_NOT_CONFIGURED",
      "S3 yükleme ayarları tamamlanmamış.",
      500,
    );
  }
  if (!bucket || !endpoint || !accessKeyId || !secretAccessKey) {
    throw new SafeError(
      "S3_NOT_CONFIGURED",
      "S3 yükleme ayarları tamamlanmamış.",
      500,
    );
  }
  return {
    provider: "s3",
    bucket,
    endpoint: normalizeEndpoint(endpoint),
    region: canonicalFirst("S3_REGION", "SOURCEBASE_S3_REGION") ||
      "us-east-1",
    accessKeyId,
    secretAccessKey,
  };
}

export function getVertexConfig(): VertexConfig {
  const supabaseUrl = getSupabaseUrl();
  const serviceRoleKey = getSupabaseServiceRoleKey();
  const vertexServiceAccountJson = canonicalFirst(
    "VERTEX_SERVICE_ACCOUNT_JSON",
    "SOURCEBASE_VERTEX_SERVICE_ACCOUNT_JSON",
    "GOOGLE_VERTEX_SERVICE_ACCOUNT_JSON",
  );
  const serviceAccount = vertexServiceAccountJson
    ? parseGoogleServiceAccount(
      vertexServiceAccountJson,
      "VERTEX_SERVICE_ACCOUNT_INVALID",
    )
    : undefined;
  const vertexProjectId = envValue(
    "VERTEX_PROJECT_ID",
    "SOURCEBASE_VERTEX_PROJECT_ID",
  ) ||
    serviceAccount?.projectId ||
    "";
  const vertexLocation = envValue(
    "VERTEX_LOCATION",
    "SOURCEBASE_VERTEX_LOCATION",
  ) ||
    "us-central1";
  const vertexModel = envValue("VERTEX_MODEL", "SOURCEBASE_VERTEX_MODEL") ||
    "gemini-2.5-flash";

  if (
    !supabaseUrl || !serviceRoleKey || !vertexProjectId ||
    !vertexServiceAccountJson || !serviceAccount
  ) {
    throw new SafeError(
      "VERTEX_NOT_CONFIGURED",
      "AI üretim yapılandırması eksik.",
      500,
    );
  }

  return {
    supabaseUrl,
    serviceRoleKey,
    vertexProjectId,
    vertexLocation,
    vertexModel,
    vertexServiceAccountJson,
    serviceAccount,
  };
}

export function runtimeConfigStatus() {
  const vertexServiceJson = canonicalFirst(
    "VERTEX_SERVICE_ACCOUNT_JSON",
    "SOURCEBASE_VERTEX_SERVICE_ACCOUNT_JSON",
    "GOOGLE_VERTEX_SERVICE_ACCOUNT_JSON",
  );
  const vertexAccount = vertexServiceJson
    ? safeParseServiceAccount(vertexServiceJson)
    : null;
  const openAiConfigured = Boolean(envValue("OPENAI_API_KEY"));
  const stabilityConfigured = Boolean(envValue("STABILITY_API_KEY"));
  const storageDriver = envValue("STORAGE_DRIVER", "SOURCEBASE_STORAGE_DRIVER")
    .toLowerCase();
  const s3Configured = Boolean(
    (canonicalFirst("S3_BUCKET", "SOURCEBASE_S3_BUCKET") ||
      "medasistorage") &&
      (canonicalFirst("S3_ENDPOINT", "SOURCEBASE_S3_ENDPOINT") ||
        "https://storage.medasi.com.tr") &&
      canonicalFirst(
        "S3_ACCESS_KEY",
        "S3_ACCESS_KEY_ID",
        "SOURCEBASE_S3_ACCESS_KEY",
        "SOURCEBASE_S3_ACCESS_KEY_ID",
      ) &&
      canonicalFirst(
        "S3_SECRET_KEY",
        "S3_SECRET_ACCESS_KEY",
        "SOURCEBASE_S3_SECRET_KEY",
        "SOURCEBASE_S3_SECRET_ACCESS_KEY",
      ),
  );

  return {
    storage: {
      provider: storageDriver || "s3",
      bucketConfigured: Boolean(
        canonicalFirst("S3_BUCKET", "SOURCEBASE_S3_BUCKET") ||
          "medasistorage",
      ),
      endpointConfigured: Boolean(
        canonicalFirst("S3_ENDPOINT", "SOURCEBASE_S3_ENDPOINT") ||
          "https://storage.medasi.com.tr",
      ),
      s3Configured,
    },
    vertex: {
      projectConfigured: Boolean(
        envValue("VERTEX_PROJECT_ID", "SOURCEBASE_VERTEX_PROJECT_ID") ||
          vertexAccount?.projectId,
      ),
      location: envValue("VERTEX_LOCATION", "SOURCEBASE_VERTEX_LOCATION") ??
        "us-central1",
      model: envValue("VERTEX_MODEL", "SOURCEBASE_VERTEX_MODEL") ??
        "gemini-2.5-flash",
      serviceAccountConfigured: Boolean(vertexServiceJson),
      serviceAccountValid: Boolean(vertexAccount),
    },
    image: {
      openAiConfigured,
      stabilityConfigured,
      providerConfigured: openAiConfigured || stabilityConfigured,
    },
    extraction: {
      clientExtractionEnabled: getClientExtractionEnabled(),
      fallback: "server",
    },
  };
}

export function parseGoogleServiceAccount(
  serviceAccountJson: string,
  errorCode: string,
): GoogleServiceAccount {
  try {
    const parsed = JSON.parse(serviceAccountJson);
    if (!isRecord(parsed)) {
      throw new Error("Service account JSON must be an object.");
    }
    const clientEmail = parsed.client_email?.toString().trim() ?? "";
    const privateKey = normalizePrivateKey(
      parsed.private_key?.toString() ?? "",
    );
    const projectId = parsed.project_id?.toString().trim() || undefined;
    if (!clientEmail || !privateKey) {
      throw new Error("Missing client_email or private_key.");
    }
    return { clientEmail, privateKey, projectId };
  } catch (_error) {
    throw new SafeError(errorCode, "Google service JSON geçersiz.", 500);
  }
}

function safeParseServiceAccount(serviceAccountJson: string) {
  try {
    return parseGoogleServiceAccount(
      serviceAccountJson,
      "SERVICE_ACCOUNT_INVALID",
    );
  } catch (_error) {
    return null;
  }
}

function firstEnv(...names: string[]) {
  for (const name of names) {
    const value = Deno.env.get(name)?.trim();
    if (!value) continue;
    if (name.endsWith("_BASE64")) {
      const decoded = decodeBase64Env(value);
      if (decoded) return decoded;
      continue;
    }
    return stripWrappingQuotes(value);
  }
  return "";
}

function canonicalFirst(canonical: string, ...aliases: string[]) {
  if (hasEnv(canonical)) {
    return firstEnv(canonical);
  }
  return firstEnv(...aliases);
}

function hasEnv(name: string) {
  return Deno.env.get(name) !== undefined;
}

function stripWrappingQuotes(value: string) {
  if (value.length < 2) return value;
  const first = value.at(0);
  const last = value.at(-1);
  if ((first === `"` && last === `"`) || (first === "'" && last === "'")) {
    return value.slice(1, -1).trim();
  }
  return value;
}

function decodeBase64Env(value: string) {
  try {
    return new TextDecoder().decode(
      Uint8Array.from(
        atob(stripWrappingQuotes(value)),
        (char) => char.charCodeAt(0),
      ),
    ).trim();
  } catch (_error) {
    return "";
  }
}

function normalizeEndpoint(value: string) {
  const cleaned = value.trim().replace(/\/+$/, "");
  return /^https?:\/\//i.test(cleaned) ? cleaned : `https://${cleaned}`;
}

function normalizePrivateKey(privateKey: string) {
  return privateKey.includes("\\n")
    ? privateKey.replaceAll("\\n", "\n")
    : privateKey;
}
