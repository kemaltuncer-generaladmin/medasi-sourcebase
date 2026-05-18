import { isRecord, SafeError } from "./types.ts";

export interface GoogleServiceAccount {
  clientEmail: string;
  privateKey: string;
  projectId?: string;
}

export interface GcsConfig {
  bucket: string;
  serviceAccountJson: string;
  serviceAccount: GoogleServiceAccount;
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

export function getGcsConfig(): GcsConfig {
  const bucket = envValue("SOURCEBASE_GCS_BUCKET", "GCS_BUCKET");
  const serviceAccountJson = firstEnv(
    "SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON",
    "GOOGLE_SERVICE_ACCOUNT_JSON",
    "GOOGLE_SERVICE_ACCOUNT_JSON_BASE64",
  );

  if (!bucket || !serviceAccountJson) {
    throw new SafeError(
      "GCS_NOT_CONFIGURED",
      "GCS yükleme ayarları tamamlanmamış.",
      500,
    );
  }

  return {
    bucket,
    serviceAccountJson,
    serviceAccount: parseGoogleServiceAccount(
      serviceAccountJson,
      "GCS_SERVICE_ACCOUNT_INVALID",
    ),
  };
}

export function getVertexConfig(): VertexConfig {
  const supabaseUrl = getSupabaseUrl();
  const serviceRoleKey = getSupabaseServiceRoleKey();
  const vertexServiceAccountJson = firstEnv(
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
  const gcsServiceJson = firstEnv(
    "SOURCEBASE_GCS_SERVICE_ACCOUNT_JSON",
    "GOOGLE_SERVICE_ACCOUNT_JSON",
    "GOOGLE_SERVICE_ACCOUNT_JSON_BASE64",
  );
  const vertexServiceJson = firstEnv(
    "VERTEX_SERVICE_ACCOUNT_JSON",
    "SOURCEBASE_VERTEX_SERVICE_ACCOUNT_JSON",
    "GOOGLE_VERTEX_SERVICE_ACCOUNT_JSON",
  );
  const vertexAccount = vertexServiceJson
    ? safeParseServiceAccount(vertexServiceJson)
    : null;

  return {
    gcs: {
      provider: "gcs",
      bucketConfigured: Boolean(
        envValue("SOURCEBASE_GCS_BUCKET", "GCS_BUCKET"),
      ),
      serviceAccountConfigured: Boolean(gcsServiceJson),
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

function normalizePrivateKey(privateKey: string) {
  return privateKey.includes("\\n")
    ? privateKey.replaceAll("\\n", "\n")
    : privateKey;
}
