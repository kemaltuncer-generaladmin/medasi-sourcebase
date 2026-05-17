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

export function getGcsConfig(): GcsConfig {
  const bucket = stripWrappingQuotes(
    Deno.env.get("SOURCEBASE_GCS_BUCKET")?.trim() ?? "",
  );
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
  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ??
    "";
  const vertexServiceAccountJson = firstEnv(
    "VERTEX_SERVICE_ACCOUNT_JSON",
    "GOOGLE_SERVICE_ACCOUNT_JSON",
    "GOOGLE_SERVICE_ACCOUNT_JSON_BASE64",
  );
  const serviceAccount = vertexServiceAccountJson
    ? parseGoogleServiceAccount(
      vertexServiceAccountJson,
      "VERTEX_SERVICE_ACCOUNT_INVALID",
    )
    : undefined;
  const vertexProjectId = Deno.env.get("VERTEX_PROJECT_ID")?.trim() ||
    serviceAccount?.projectId ||
    "";
  const vertexLocation = Deno.env.get("VERTEX_LOCATION")?.trim() ||
    "us-central1";
  const vertexModel = Deno.env.get("VERTEX_MODEL")?.trim() ||
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
    "GOOGLE_SERVICE_ACCOUNT_JSON",
    "GOOGLE_SERVICE_ACCOUNT_JSON_BASE64",
  );
  const vertexAccount = vertexServiceJson
    ? safeParseServiceAccount(vertexServiceJson)
    : null;

  return {
    gcs: {
      provider: "gcs",
      bucketConfigured: Boolean(Deno.env.get("SOURCEBASE_GCS_BUCKET")),
      serviceAccountConfigured: Boolean(gcsServiceJson),
    },
    vertex: {
      projectConfigured: Boolean(
        Deno.env.get("VERTEX_PROJECT_ID") || vertexAccount?.projectId,
      ),
      location: Deno.env.get("VERTEX_LOCATION") ?? "us-central1",
      model: Deno.env.get("VERTEX_MODEL") ?? "gemini-2.5-flash",
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
      Uint8Array.from(atob(stripWrappingQuotes(value)), (char) =>
        char.charCodeAt(0)
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
