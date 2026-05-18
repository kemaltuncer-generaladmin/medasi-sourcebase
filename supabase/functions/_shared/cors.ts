const DEFAULT_ALLOWED_ORIGIN = "https://sourcebase.medasi.com.tr";

export const corsHeaders = {
  "Access-Control-Allow-Origin": allowedCorsOrigin(),
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function allowedCorsOrigin() {
  const configured = Deno.env.get("SOURCEBASE_ALLOWED_ORIGIN")?.trim();
  if (!configured || configured === "*") return DEFAULT_ALLOWED_ORIGIN;
  return configured;
}
