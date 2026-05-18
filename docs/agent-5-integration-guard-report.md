# Agent 5 Integration Guard Report

Date: 2026-05-19
Branch/worktree: `agent-5-integration-guard`
Scope: merge safety, integration regression risk, security regression review, Qlinik impact review, final QA/deploy/rollback coordination.

## Executive Summary

- P0: `origin/main` and the active agent branches have no Git merge-base. A normal three-dot comparison and normal merge planning against `origin/main` are not reliable until history is reconciled.
- P1: The requested branch names `agent-1-drive-ingestion`, `agent-2-baseforce`, `agent-3-sourcelab-ai`, `agent-4-profile-store-state`, and `agent-5-integration-guard` all point to the same commit: `1eb709243d5bd0551dd3eac2c5bf696ed598a9fd`.
- P1: Because those five branches are identical, every changed file is reported as touched by every agent branch. This is a branch hygiene/coordination issue, not five independent conflict sets.
- P1: The older topic branches under `agent/...` still show the expected independent change surface and real overlap risk. They should be treated as reference branches unless explicitly selected for integration.

## Branch/Diff Matrix

Primary comparison notes:

- `git merge-base origin/main agent-1-drive-ingestion` failed: no merge base.
- `git diff origin/main <agent-branch>` is therefore a tree-to-tree comparison only, not a safe merge preview.
- `main-safe-backup` has a valid merge-base with the active agent branches and was used as the practical baseline for risk review.

Active requested branches:

| Branch | Head | vs `origin/main` tree diff | vs `main-safe-backup` merge-base diff | Notes |
| --- | --- | ---: | ---: | --- |
| `agent-1-drive-ingestion` | `1eb7092` | 169 files | 88 files | Same head as agents 2-5 |
| `agent-2-baseforce` | `1eb7092` | 169 files | 88 files | Same head as agents 1,3,4,5 |
| `agent-3-sourcelab-ai` | `1eb7092` | 169 files | 88 files | Same head as agents 1,2,4,5 |
| `agent-4-profile-store-state` | `1eb7092` | 169 files | 88 files | Same head as agents 1,2,3,5 |
| `agent-5-integration-guard` | `1eb7092` | 169 files before this report | 88 files before this report | This report is the only intended Agent 5 work product |

Reference topic branches present in repo:

| Branch | vs `main-safe-backup` changed files | Primary area |
| --- | ---: | --- |
| `agent/drive-upload-flow` | 18 | Drive upload flow |
| `agent/backend-ai-security` | 29 | SourceBase Edge/security hardening |
| `agent/baseforce-sourcelab-flow` | 7 | BaseForce, SourceLab, Central AI UI |
| `agent/profile-store-flow` | 8 | Profile/store/session UI |
| `agent/auth-flow` | 11 | Auth UI/backend |
| `integration-candidate` | 70 | Merged candidate from topic branches |

## Conflict Risk

Active requested branches:

- Since agents 1-5 are identical heads, any sequential merge of those branch names after the first should be a no-op.
- The conflict risk is high if teams assume these branches contain separate work. They do not currently provide attribution or isolation.
- Every file in the 88-file `main-safe-backup...agent-5-integration-guard` diff appears as touched by all five active agent branch names.

Highest-risk shared files in the reference `agent/...` topic branches:

| File | Branches | Risk |
| --- | --- | --- |
| `lib/features/sourcelab/presentation/screens/source_lab_screen.dart` | auth, backend-ai-security, baseforce-sourcelab, drive-upload, profile-store | Very high: large UI file touched by all reference topics |
| `lib/features/drive/data/drive_repository.dart` | drive-upload, baseforce-sourcelab | Medium/high: source selection and generation flow coupling |
| `lib/features/drive/data/sourcebase_drive_api.dart` | drive-upload, baseforce-sourcelab | Medium/high: API contract coupling |
| `lib/features/drive/presentation/widgets/drive_ui.dart` | drive-upload, baseforce-sourcelab | Medium: shared UI/status rendering |
| `lib/features/drive/presentation/widgets/sourcebase_bottom_nav.dart` | drive-upload, baseforce-sourcelab | Medium: navigation regression risk |
| `lib/features/baseforce/presentation/screens/baseforce_screen.dart` | baseforce-sourcelab, profile-store | High: very large UI file and generation flow |
| `lib/app/sourcebase_app.dart` | auth, profile-store | Medium/high: route/session interaction |
| `lib/features/auth/presentation/screens/login_screen.dart` | auth, profile-store | Medium/high: session/login UX coupling |
| `lib/features/auth/presentation/widgets/auth_widgets.dart` | auth, profile-store | Medium: shared auth UI components |

## Security Regression Checklist

| Check | Result | Evidence/notes |
| --- | --- | --- |
| `complete_upload` fake upload patch preserved | Pass | `completeUpload` reads GCS object metadata and calls `assertCompletedUploadMatches` before inserting `drive_files`. It also rejects non-positive `sizeBytes`. |
| `process_generation_job` patch preserved | Pass | `processGenerationJob` explicitly processes the job synchronously via `processor.processJob(...)` and returns completed token/cost status. |
| `create_generation_job` reverted to fire-and-forget | Pass | `createGenerationJob` creates a queued job and returns the job id/status. No `setTimeout`, `waitUntil`, or detached background processing was found in the sourcebase function. |
| Secrets/tokens/private keys printed to logs | Needs final scan | Code logs provider/status/error codes, not credential values. Final regex scan is still required before commit. |
| Service role/anon tokens returned to UI | Pass by review | Service keys are used server-side for REST calls; responses reviewed in critical paths do not include key values. |
| CORS loosened further | Pass with note | `_shared/cors.ts` and `sourcebase/index.ts` fall back from `*` to `https://sourcebase.medasi.com.tr`; GCS CORS allows production plus localhost dev origins only. |
| Raw provider/backend error leaks to UI | Partial risk | BaseForce and SourceLab map common provider/config errors to friendly messages, but unknown errors still return sanitized text after framework-prefix stripping. Keep this in smoke tests. |
| Failed/0KB resources selectable for generation | Pass by review | Upload validation rejects `sizeBytes <= 0`; Drive generation is blocked unless `DriveItemStatus.completed`. |
| Audit/log metadata exposes object names | Acceptable risk | `complete_upload` audit metadata includes `objectName`; this is not a secret but should not be shown to end users. |

## Qlinik Impact Checklist

| Check | Result | Notes |
| --- | --- | --- |
| Qlinik-specific files touched | Pass | `rg --files | rg -i 'qlinik'` returned no paths. |
| Shared auth/backend files touched | Risk accepted | `lib/features/auth/data/sourcebase_auth_backend.dart`, `lib/app/sourcebase_app.dart`, `_shared/cors.ts`, and `_shared/supabase-client.ts` changed in active diff. These are SourceBase-shared surfaces and require auth smoke tests. |
| SourceBase Edge README says Qlinik | P1 docs risk | `supabase/functions/sourcebase/README.md` labels the function as “Qlinik Edge Function.” This should be corrected in a future docs-only change if it is inaccurate. |
| Runtime Qlinik business logic changed | Pass by review | No Qlinik module was found or edited. |

## Merge Order

Recommended order, given the user-requested branch labels:

1. Agent 1: `agent-1-drive-ingestion`
2. Agent 2: `agent-2-baseforce`
3. Agent 3: `agent-3-sourcelab-ai`
4. Agent 4: `agent-4-profile-store-state`
5. Agent 5: `agent-5-integration-guard` final docs/checklist

Operational note:

- With the current branch state, merging Agent 1 first brings in the same commit as Agents 2-5. Agents 2-4 should then be verified as no-op merges, not assumed to add independent work.
- Do not merge directly into `origin/main` until the no-merge-base condition is resolved. Use a protected integration branch and verify the resulting tree against the intended deploy candidate.

## Final Test Checklist

Required commands before release/commit:

```bash
deno check supabase/functions/sourcebase/index.ts
deno check supabase/functions/ai-services/index.ts
flutter analyze
flutter test
flutter build web
git diff --check
```

Additional recommended checks:

```bash
deno test supabase/functions/sourcebase/services/file-types.test.ts supabase/functions/sourcebase/services/extraction.test.ts
git status --short --branch
git diff --stat
```

Manual smoke checklist:

- Auth: register/login/logout, email callback route, expired session recovery.
- Drive upload: PDF, DOCX, PPTX; reject 0KB; reject unsupported file; verify failed uploads cannot generate.
- Generation: create job, process job, status poll, generated content retrieval.
- BaseForce: algorithm/comparison/table friendly failure messages.
- SourceLab: infographic/mind map/clinical/plan friendly failure messages.
- Central AI: message send, provider failure fallback, no raw stack/provider payload.
- Profile/store: wallet balance display, disabled/guarded purchase path, session refresh.
- CORS: production origin succeeds; unrelated origin is not widened by configuration.

## Live Edge Deploy Plan

Do not mix this with frontend deploy.

Preconditions:

- Tests above pass on the exact commit being deployed.
- Current production Edge function versions are noted for rollback.
- Required Supabase secrets already exist in the target environment; do not print them.
- Frontend deployment remains frozen unless separately approved.

Plan:

```bash
# 1. Sync only SourceBase Edge function code to the deployment host.
rsync -av --delete supabase/functions/sourcebase/ <DEPLOY_HOST>:<APP_PATH>/supabase/functions/sourcebase/

# 2. Sync only ai-services Edge function code to the deployment host.
rsync -av --delete supabase/functions/ai-services/ <DEPLOY_HOST>:<APP_PATH>/supabase/functions/ai-services/

# 3. Recreate only the Edge functions container/service.
docker compose up -d --force-recreate --no-deps supabase-edge-functions

# 4. Smoke only Edge endpoints and SourceBase flows.
# Do not trigger frontend build/deploy in this step.
```

Deployment guardrails:

- Do not rsync `.env`, local secrets, build artifacts, or unrelated frontend files.
- Do not recreate database, storage, frontend, or reverse proxy services as part of this Edge-only deploy.
- Capture logs only for status/error codes. Do not paste bearer tokens, service keys, private keys, or signed URLs into tickets/chat.

## Rollback Plan

Preferred rollback:

1. Identify the last known-good Edge function commit/artifact.
2. Rsync only `supabase/functions/sourcebase/` and `supabase/functions/ai-services/` from last known-good artifact.
3. Recreate only `supabase-edge-functions`.
4. Run Edge smoke tests: auth-required request rejection, `load_bundle`, upload init/complete with known fixture, generation job status.
5. Keep frontend unchanged.

Emergency rollback:

1. Stop or recreate only `supabase-edge-functions` using the previous image/container configuration.
2. Disable only newly introduced generation actions if feature flags/env controls exist.
3. Preserve data; do not rollback migrations without a reviewed DB restore plan.
4. If wallet reservation/capture anomalies occur, pause paid generation actions and reconcile `medasicoin_transactions` before re-enabling.

## P0/P1 Remaining Risks

P0:

- `origin/main` has no merge-base with the active agent branches. This must be resolved before a normal protected merge to main.

P1:

- Active agent branches 1-5 are identical heads, so attribution and independent merge ordering are unreliable.
- Large shared UI files remain high regression surfaces: SourceLab and BaseForce especially.
- Unknown backend/provider errors may still surface as sanitized text in some UI paths; smoke tests must cover failure modes.
- Shared auth/CORS/Supabase helper files changed; Qlinik-specific files were not found, but auth/session smoke is required.
- Edge deploy must stay separate from frontend deploy to avoid expanding rollback scope.
