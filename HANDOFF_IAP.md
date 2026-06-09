# Cross-App IAP / Subscriptions / ASSN — Handoff (2026-06-10)

Continuation doc for another agent. Covers the 3-app (SourceBase, Qlinik, Praticase)
shared subscription + App Store Server Notification (ASSN) work.

## TL;DR state
- **All fixes are SERVER-SIDE and LIVE.** No iOS build was changed. No build is required to ship the bug fixes.
- ASSN webhook live + verified SUCCESS for all 3 apps → `https://api.medasi.com.tr/functions/v1/sourcebase`.
- SourceBase app v1.0 + its 4 storage subscriptions are `WAITING_FOR_REVIEW` (Apple-gated, first submission). Qlinik 2.5.0 + Praticase 1.0.3 are `READY_FOR_SALE` (live).
- Integrity sweep clean (no stuck/duplicate/orphaned active subs, no balance drift).

## Server access
- SSH: `ssh root@46.225.100.139` (Coolify host). Service UUID `yiqde9ihk4ud8gxrymld1jx7`.
- Edge functions container: `supabase-edge-functions-yiqde9ihk4ud8gxrymld1jx7`
- DB container: `supabase-db-yiqde9ihk4ud8gxrymld1jx7` (psql -U postgres -d postgres). Function owner is `supabase_admin` — apply CREATE OR REPLACE on shared functions as `-U supabase_admin`.
- Coolify service dir: `/data/coolify/services/yiqde9ihk4ud8gxrymld1jx7/` (has `.env`, `docker-compose.yml`, `volumes/functions/`, `secrets/`).

## Edge function deploy (IMPORTANT gotcha)
The `sourcebase` function source is bind-mounted at
`/data/coolify/services/yiqde9ihk4ud8gxrymld1jx7/volumes/functions/sourcebase/index.ts`.
Repo copy: `supabase/functions/sourcebase/index.ts` (kept in sync — scp this up).

Deploy steps:
```bash
scp local/index.ts root@46.225.100.139:/tmp/x.ts
ssh root@46.225.100.139 "cp /tmp/x.ts /data/coolify/services/yiqde9ihk4ud8gxrymld1jx7/volumes/functions/sourcebase/index.ts && docker restart supabase-edge-functions-yiqde9ihk4ud8gxrymld1jx7"
```
**GOTCHA:** `docker compose up -d` often leaves the container "Running" (no recreate) and the edge runtime serves the CACHED compiled module. ALWAYS `docker restart` the edge-functions container to load new code. Verify with a smoke test (below).

## ASC / App Store Server API key (embedded on server)
- New key kid `63S2PP6KZU`, issuer `1c52f93c-3f04-490c-ab39-1781205e1f31`. NEVER print .p8.
- `.p8` on server: `/data/coolify/services/yiqde9ihk4ud8gxrymld1jx7/secrets/AuthKey_63S2PP6KZU.p8` (chmod 600). Also local `~/Downloads/AuthKey_63S2PP6KZU.p8`.
- `.env` vars wired into edge: `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`, `ASC_API_PRIVATE_KEY_BASE64` (also in docker-compose.yml edge env block).
- Works for BOTH ASC API (`api.appstoreconnect.apple.com`, JWT aud=appstoreconnect-v1) AND App Store Server API (`api.storekit-sandbox.itunes.apple.com`, JWT needs extra `bid` claim).
- Token gens (local): `~/.ascwork/gen_token.py` (ASC) and `~/.ascwork/gen_token_bid.py <bundleId>` (Server API). Use `/usr/local/bin/python3` (has cryptography; system 3.14 lacks it). curl needs `-g` for `fields[apps]`.

## App / product IDs
- SourceBase app `6770117628` (tr.com.medasi.sourcebase); sub group `22142682`; subs: 15gb `6778059889`, 25gb `6778059572`, 50gb `6778059922`, pro `6778069766`. All WAITING_FOR_REVIEW (prices set).
- Qlinik app `6769012338` (com.medasi.qlinik). Praticase app `6771926735` (com.medasi.praticase).
- ASSN URL set via `PATCH /v1/apps/{id}` attrs `subscriptionStatusUrl`/`...ForSandbox`/`...Version`="V2" → all 3 point to `https://api.medasi.com.tr/functions/v1/sourcebase`. Propagation to delivery ~2-10 min.
- Test a notification: `POST https://api.storekit-sandbox.itunes.apple.com/inApps/v1/notifications/test` (JWT w/ bid) → token; then GET `.../test/{token}` → `firstSendAttemptResult` (SUCCESS expected).

## api.medasi.com.tr (HTTPS endpoint)
- Cloudflare A record `api → 46.225.100.139` (DNS-only/grey). Traefik HTTPS router added to Supabase Kong labels in `docker-compose.yml` (routers `http-api-medasi-kong` + `https-api-medasi-kong`, certresolver=letsencrypt, svc port 8000). Valid Let's Encrypt cert.
- Smoke test (should return ASSN_VERIFY_FAILED 400, proving routing+verify): 
  `curl -s "https://api.medasi.com.tr/functions/v1/sourcebase" -X POST -H "Content-Type: application/json" -d '{"signedPayload":"x"}'`

## Architecture (shared schema)
- All 3 apps share `public.purchases` + `public.wallet_entitlements` + `public.apply_purchase_grant` + `public.sync_wallet_profile` + `public.grant_store_product`. Per-app scoping via `purchases.raw_receipt->>'app_key'` ('sourcebase'|'qlinik'|'praticase'; default fallback 'qlinik').
- SourceBase storage uses `sourcebase.storage_subscriptions` (separate table; bonus = max active tier where expires_at>now()).
- ASSN handler `handleAppStoreServerNotification` (in sourcebase index.ts): verifies Apple JWS (outer envelope + inner signedTransactionInfo), `allowedBundleIds()` gate (env `ALLOWED_APPSTORE_BUNDLE_IDS` = all 3 bundles), then:
  - storage products → update `storage_subscriptions` + `cascadeStorageSubscriptions()`.
  - EXPIRED/REFUND/REVOKE (any app) → `revokeSharedEntitlementByTxn(txnIds, appKey, status)` revokes matching active wallet_entitlements (matched by provider_transaction_id raw or `appstore:`-prefixed, app_key-scoped) + re-syncs wallet.

## Bugs fixed this saga (all deployed + LIVE)
1. `public.apply_purchase_grant` 10-minute renewal window removed (migration `supabase/migrations/20260609120000_*`). Apple sends prod renewals up to 24h early → every renewal raised "Active subscription exists" (23505). Now any same-product+app renewal is accepted; `WHERE expires_at>now()` gates it.
2. `supabaseRest`+`sharedSupabaseRest` had no timeout → Pro MC grant could hang → edge isolate wall-clock kill → iOS "bakiye güncellenemedi". Added `signal: AbortSignal.timeout(8000)`.
3. `sourcebase.audit_logs.entity_id` is uuid; redeem passed an App Store originalTransactionId (numeric string) → PostgREST "invalid uuid" → DATABASE_ERROR after the storage row was already written. Fixed `audit()` to only set entity_id when valid uuid (else null + metadata.entity_ref) AND wrapped in try/catch (audit never breaks a purchase).
4. ASSN raw format: Apple POSTs `{"signedPayload":"<jws>"}` (no `action`). Main handler now routes both `action==="appstore_server_notification"` and top-level `body.signedPayload`. Without it Apple got 401 (UNSUCCESSFUL_HTTP_RESPONSE_CODE).
5. Cancellation (DID_CHANGE_RENEWAL_STATUS/AUTO_RENEW_DISABLED) no longer expires storage immediately — kept access until expires_at (Apple keeps cancelled subs active until period end; `expires_at>now()` filter drops automatically). isExpired now only EXPIRED/REFUND/REVOKE.
6. `cascadeStorageSubscriptions()` enforces single active storage tier per user (rank via storageTierRank; ties→latest expiry; others→'superseded'). Called after storage redeem + ASSN active events.
7. Cross-app revocation (#revokeSharedEntitlementByTxn) so refund/revoke reflects for all 3 apps.

## Tests (all PASS, run on prod DB inside BEGIN/ROLLBACK — nothing persists)
- `supabase/tests/test_apply_purchase_grant.sql` — fresh / early-renewal / cross-app isolation / weekly→monthly upgrade / idempotency.
- `supabase/tests/test_assn_cascade_revoke.sql` — storage cascade / refund-revoke / app-scope guard.
Run: `ssh root@46.225.100.139 "docker exec -i supabase-db-... psql -U postgres -d postgres" < test.sql`. Note: use synthetic provider_transaction_id (real ones hit the unique idx on (provider, provider_transaction_id)).
- Integrity sweep query (read-only) lived at `/tmp/integrity.sql` (re-create if gone): checks stuck active-past-expiry subs, duplicate active per (user,app,product), storage cascade violations, orphaned active entitlements, wallet_balance drift. Last run: all clean. `sync_wallet_profile(user)` self-heals drift (it expires past-due active entitlements then recomputes balance).

## ASSN renewal-grant — DONE (2026-06-10, deployed + tested)
- `grantSharedRenewalByTxn(originalTransactionId, transactionId, appKey, expiresAt)` in sourcebase index.ts. On DID_RENEW/SUBSCRIBED for NON-storage products: finds the prior purchase for the originalTransactionId (reuses its product_id — no fragile productId→code map), inserts a renewal purchase keyed `assn:<transactionId>`, calls apply_purchase_grant. Idempotent via the unique (provider, provider_transaction_id) index; fully wrapped in try/catch (client redeem stays the backstop). app_key-scoped.
- Validated: `supabase/tests/test_assn_renewal.sql` — TEST 9 (renewal expires old + grants fresh +30d/100MC) + TEST 10 (duplicate assn txn blocked, no double grant). Both PASS.
- So Qlinik/Praticase renewals now reflect server-side even with the app closed. SourceBase storage renewals handled by the storage block; SourceBase Pro MC still refreshes on app-open redeem (storage block updates storage_subscriptions, not the MC entitlement — acceptable, low impact).

## iOS client change — downgrade UX (2026-06-10, needs a SourceBase build to ship)
First Swift change of this saga (everything else was server-side). Storage plan DOWNGRADE (e.g. Pro→50GB) is deferred by Apple to the next renewal — the old flow showed "etkinleşti" (wrong) and Apple's "already subscribed" sheet confused users. Changes in `SourceBaseiOS/.../Features/Profile/StoreView.swift` + `SBStorageProduct.swift`:
- `SBStorageProduct.displayName` ("15 GB"/"25 GB"/"50 GB"/"Pro").
- Tapping "Düşür" now opens a confirmation alert (`pendingDowngrade` state) explaining the period-end timing BEFORE Apple's sheet; only on confirm does it purchase.
- `purchaseStorage(_:isDowngrade:)` shows scheduled-change copy (not "etkinleşti") on a downgrade, and a soft reassurance (not a hard error) if Apple reports it's already scheduled.
- Section description updated: "Yükseltme hemen; düşürme ve iptal dönem sonunda devreye girer."
- Build verified (`xcodebuild ... BUILD SUCCEEDED`). Server already handles the actual downgrade at renewal (storage block patches the row to the new tier by originalTransactionId; Pro MC expires naturally).

## Future (needs iOS builds — NOT bugs)
- Cross-app PURCHASING UI: Qlinik/Praticase show+sell SourceBase storage subs; SourceBase handle currentEntitlements from other bundle IDs. Backend already accepts cross-app JWS (ALLOWED_APPSTORE_BUNDLE_IDS).

## Memory
Full detail also in user memory `sourcebase-cross-app-iap.md` and `sourcebase-appstore-connect.md`.
