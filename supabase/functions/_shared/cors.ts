const DEFAULT_ALLOWED_ORIGIN = "https://sourcebase.medasi.com.tr";

export const corsHeaders = {
  "Access-Control-Allow-Origin": allowedCorsOrigin(),
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function allowedCorsOrigin() {
  const configured = envValue(
    "SOURCEBASE_ALLOWED_ORIGIN",
    "SOURCEBASE_PUBLIC_URL",
  );
  if (!configured || configured === "*") return DEFAULT_ALLOWED_ORIGIN;
  return configured;
}

function envValue(...names: string[]) {
  for (const name of names) {
    const value = Deno.env.get(name)?.trim();
    if (value) return value;
  }
  return "";
}
