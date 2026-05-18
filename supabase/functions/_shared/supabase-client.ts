import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function envValue(...names: string[]) {
  for (const name of names) {
    const value = Deno.env.get(name)?.trim();
    if (value) return value;
  }
  return "";
}

export const supabaseAdmin = createClient(
  envValue("SUPABASE_URL", "SOURCEBASE_SUPABASE_URL"),
  envValue(
    "SUPABASE_SERVICE_ROLE_KEY",
    "SOURCEBASE_SUPABASE_SERVICE_ROLE_KEY",
    "SUPABASE_SERVICE_KEY",
  ),
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
    db: {
      schema: "sourcebase",
    },
  },
);
