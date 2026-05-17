export const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("SOURCEBASE_ALLOWED_ORIGIN") ??
    "https://sourcebase.medasi.com.tr",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
