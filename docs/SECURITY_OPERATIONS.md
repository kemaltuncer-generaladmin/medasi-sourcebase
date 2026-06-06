# SourceBase Security Operations

## Supabase Client Key Model

The baked `SourceBaseConfig.Defaults.supabaseAnonKey` is a Supabase anon client token. It is expected to ship in the iOS binary and is not a service-role secret.

Security must come from Supabase Row Level Security and Edge Function authorization, not from hiding the anon key.

## Pre-Launch Checks

- Confirm RLS is enabled on every SourceBase table that can contain user, Drive, wallet, purchase, or generated-output data.
- Confirm no `service_role` key exists in app, package, docs, tests, build scripts, or copied sample files.
- Confirm StoreKit redemption validates transaction JWS, bundle id `tr.com.medasi.sourcebase`, product id, and idempotency before crediting MC.
- Confirm App Store Connect product ids match `MedasiCoinPackage.appStoreProductId`.

## Rotation Runbook

1. Create or rotate the Supabase anon key in the Supabase project.
2. Deploy the backend and Edge Functions with the same project configuration.
3. Update `SourceBaseConfig.Defaults.supabaseAnonKey` for the next iOS build.
4. Submit an expedited app update if the old key must be revoked immediately.
5. Verify sign-in, workspace load, upload session creation, StoreKit redeem, and profile load with the new build.

Never put a Supabase service-role key, Apple private key, App Store Connect `.p8`, JWT signing key, password, or production secret in the repo.
