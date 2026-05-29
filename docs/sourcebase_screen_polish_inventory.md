# SourceBase — Screen Polish Inventory

**Baseline:** `claude/sourcebase-wow-polish` @ `f4b5cd8`
**Sprint:** full screen-by-screen visual/product polish, 2026-05-29
**Author:** Claude (Anthropic) — senior mobile product designer + Flutter UI engineer

## How this inventory was built

I read every screen file in `lib/features/**/presentation/` and walked the `app/sourcebase_app.dart` shell, plus the core design system in `lib/core/design_system/**` and `lib/core/theme/app_colors.dart`. I cross-checked the premium component library (`premium_workspace_components.dart`, `drive_ui.dart`, `generated_output_readers.dart`).

**Honest limitation:** I do not have an iPhone simulator or screenshot capability in this environment. I can compile (`flutter build web` passes) but I cannot interactively view the running UI. Items marked **Needs live screenshot/QA** are ones where source reads were inconclusive — only running the build will settle them.

I deliberately do not invent new visual systems; everything below assumes the existing premium palette (mavi/lacivert) and Codex's component vocabulary.

## Legend

- **Quality:** Excellent / Good / Acceptable / Weak / Bad
- **Decision:** Patch now / Leave unchanged / Needs live screenshot
- **Priority:** P0 (must patch this sprint) / P1 (should patch) / P2 (nice to have)
- **Risk:** Low / Medium / High (likelihood of breaking flow if patched)

## 1. App shell / auth bridge / splash

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| Auth-protected bridge loader | [sourcebase_app.dart](lib/app/sourcebase_app.dart) | Excellent | already patched in `382340b` | — | — | — | Leave unchanged |
| Drive workspace bootstrap loader | [drive_workspace_screen.dart](lib/features/drive/presentation/screens/drive_workspace_screen.dart) | Excellent | already patched in `382340b` | — | — | — | Leave unchanged |
| Drive workspace error state (`_ErrorState`) | [drive_workspace_screen.dart:1557](lib/features/drive/presentation/screens/drive_workspace_screen.dart:1557) | Good | calm, premium retry button | — | — | — | Leave unchanged |

## 2. Auth screens

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| Login | [login_screen.dart](lib/features/auth/presentation/screens/login_screen.dart) | Good | duplicated "Hesap Oluştur" CTA + "Hesabın yok mu? Kayıt ol" text link at bottom | collapse to one, keep secondary button | P1 | Low | Patch now |
| Register | [register_screen.dart](lib/features/auth/presentation/screens/register_screen.dart) | Good | mirrors login: duplicated "Giriş Yap" CTA + "Zaten hesabın var mı? Giriş yap" link | collapse to one | P1 | Low | Patch now |
| Forgot password | [forgot_password_screen.dart](lib/features/auth/presentation/screens/forgot_password_screen.dart) | Excellent | uses SourceBaseCard info chip + Gradient/Outline buttons; clear scope | — | — | — | Leave unchanged |
| Verify email (OTP) | [verify_email_screen.dart](lib/features/auth/presentation/screens/verify_email_screen.dart) | Acceptable | 6-digit OTP + countdown; visual quality of OTP cells unknown without running | — | P2 | Med | Needs live screenshot |
| Profile setup | [profile_setup_screen.dart](lib/features/auth/presentation/screens/profile_setup_screen.dart) | Acceptable | small file, uses auth widgets; unread fully | — | P2 | Low | Needs live screenshot |
| AuthScreenFrame (background painter + card sleeve) | [auth_widgets.dart](lib/features/auth/presentation/widgets/auth_widgets.dart) | Excellent | painted background, card sleeve at ≥700px width, keyboard inset handled | — | — | — | Leave unchanged |
| AuthHeader (with brand + art) | [auth_widgets.dart:88](lib/features/auth/presentation/widgets/auth_widgets.dart:88) | Excellent | adaptive sizing, semantic group | — | — | — | Leave unchanged |
| AuthTextField | [auth_widgets.dart:150](lib/features/auth/presentation/widgets/auth_widgets.dart:150) | Excellent | premium-shadowed input with leading icon, trailing slot | — | — | — | Leave unchanged |
| AuthStatusBox | [auth_widgets.dart:381](lib/features/auth/presentation/widgets/auth_widgets.dart:381) | Excellent | red/green tinted card | — | — | — | Leave unchanged |

## 3. Drive — home / workspace

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| Drive home — hero | [drive_home_screen.dart:170](lib/features/drive/presentation/screens/drive_home_screen.dart:170) | Excellent | PremiumEmptyState with badges + CTA | — | — | — | Leave unchanged |
| Drive home — `_CourseEmptyPanel` | [drive_home_screen.dart:680](lib/features/drive/presentation/screens/drive_home_screen.dart:680) | Excellent | DriveEmptyArt + hierarchical text + SBSecondaryButton | — | — | — | Leave unchanged |
| Drive home — `_StorageSummaryCard` (uploads/collections empty) | [drive_home_screen.dart:732](lib/features/drive/presentation/screens/drive_home_screen.dart:732) | Excellent | icon + message + subMessage | — | — | — | Leave unchanged |
| Drive home — course actions sheet | [drive_home_screen.dart:1200](lib/features/drive/presentation/screens/drive_home_screen.dart:1200) | Good | 3-action sheet, has SafeArea + dragHandle; not isScrollControlled but only 3 items so OK | — | — | — | Leave unchanged |

## 4. Drive — uploads / source ingest

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| Uploads screen — hero + guidance | [uploads_screen.dart](lib/features/drive/presentation/screens/uploads_screen.dart) | Excellent | PremiumHeroCard with 4 metric pills + `_UploadGuidancePanel` explaining what's supported | — | — | — | Leave unchanged |
| Uploads screen — empty states (no uploads / no filter results) | [uploads_screen.dart:165](lib/features/drive/presentation/screens/uploads_screen.dart:165) | Excellent | premium states with icons + badges + CTA | — | — | — | Leave unchanged |
| **Uploads screen — uploading / processing visual** | [uploads_screen.dart:528-546](lib/features/drive/presentation/screens/uploads_screen.dart:528) | **Weak** | progress shown only as text tag `İlerleme 42%` inside ProcessingCard; **no actual progress bar** visible. `_ProgressStatus` widget that draws a LinearProgressIndicator is defined at line 593 but **never instantiated** (note `unused_element` ignore at file top) | wire `_ProgressStatus` (or inline LinearProgressIndicator) into `_UploadState` so uploading/processing rows show a real bar that reflects `upload.progress` | **P0** | Low | **Patch now** |
| Uploads screen — failed row | [uploads_screen.dart:497-527](lib/features/drive/presentation/screens/uploads_screen.dart:497) | Good | red badge + friendly error + retry button | — | — | — | Leave unchanged |
| Uploads screen — ready row | [uploads_screen.dart:481-496](lib/features/drive/presentation/screens/uploads_screen.dart:481) | Good | green "Hazır" badge + reassurance copy | — | — | — | Leave unchanged |

## 5. Drive — file list / detail / search / folders

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| File detail — header card | [file_detail_screen.dart:48](lib/features/drive/presentation/screens/file_detail_screen.dart:48) | Excellent | FileKindBadge + title + meta wrap + StatusPill + course breadcrumb | — | — | — | Leave unchanged |
| File detail — readiness notice | [file_detail_screen.dart:434](lib/features/drive/presentation/screens/file_detail_screen.dart:434) | Excellent | status-aware (already patched in `eadcab6`) | — | — | — | Leave unchanged |
| File detail — Üretim merkezleri panel | [file_detail_screen.dart:359](lib/features/drive/presentation/screens/file_detail_screen.dart:359) | Good | disabled-state shows lock icon; subtitle uses readinessMessage which can overflow to 2 lines — acceptable | — | — | — | Leave unchanged |
| File detail — generated outputs section | [file_detail_screen.dart:302](lib/features/drive/presentation/screens/file_detail_screen.dart:302) | Excellent | EmptyState with academic copy | — | — | — | Leave unchanged |
| Drive search — empty (no query) | [drive_search_screen.dart:307](lib/features/drive/presentation/screens/drive_search_screen.dart:307) | Excellent | PremiumEmptyState with badges | — | — | — | Leave unchanged |
| Drive search — no matches | [drive_search_screen.dart:314](lib/features/drive/presentation/screens/drive_search_screen.dart:314) | Excellent | PremiumEmptyState with "Filtreleri temizle" CTA | — | — | — | Leave unchanged |
| Drive search — filter sheets (kind/status/option) | [drive_search_screen.dart:337](lib/features/drive/presentation/screens/drive_search_screen.dart:337) | Good | 5-6 option choice sheets with SafeArea; not isScrollControlled but lists are short | — | — | — | Leave unchanged |
| Folder screen — filter sheets | [folder_screen.dart:420](lib/features/drive/presentation/screens/folder_screen.dart:420) | Good | as above | — | — | — | Leave unchanged |
| Course detail | course_detail_screen.dart | Acceptable | 1741 lines, unread in full; structure mirrors folder; unknown whether all states use premium components | — | P2 | Med | Needs live screenshot |
| Collections screen | collections_screen.dart | Acceptable | 836 lines, unread in full | — | P2 | Med | Needs live screenshot |

## 6. Drive — source picker sheets

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| SourceLab Drive source picker sheet | [source_lab_screen.dart:398](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:398) | Excellent | already isScrollControlled + maxHeight 0.86 in `c512b0d` | — | — | — | Leave unchanged |
| BaseForce source picker sheet | baseforce_screen.dart | Acceptable | not directly inspected this turn; per memory it shares the same shape | — | P2 | Med | Needs live screenshot |
| Central AI context picker (inline ListView, not modal) | [central_ai_screen.dart:418](lib/features/central_ai/presentation/screens/central_ai_screen.dart:418) | Good | horizontal scroll inside ContextPanel | — | — | — | Leave unchanged |

## 7. BaseForce — generation flows

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| BaseForce hub | baseforce_screen.dart | Acceptable | factory cards present (`_FactoryCard` at line 5415); not fully read | — | P2 | Med | Needs live screenshot |
| Flashcard Factory setup | [baseforce_screen.dart:2273](lib/features/baseforce/presentation/screens/baseforce_screen.dart:2273) | Excellent | `_FactoryIdentityCard` header + `_SourcesPanel` + `_BasePanel` settings with segment buttons + stepper | — | — | — | Leave unchanged |
| Flashcard result screen (`_FlashcardResultsScreen`) | [baseforce_screen.dart:3633](lib/features/baseforce/presentation/screens/baseforce_screen.dart:3633) | Acceptable | unread fully | — | P2 | Med | Needs live screenshot |
| Question / Summary / Algorithm / Comparison factories | baseforce_screen.dart:2531, :2719, :2868, :3207 | Acceptable | same shape as Flashcard; unread in full | — | P2 | Med | Needs live screenshot |
| `_EmptyBaseForceState` (when no source ready) | [baseforce_screen.dart:5144](lib/features/baseforce/presentation/screens/baseforce_screen.dart:5144) | Excellent | CircleAvatar + premium type | — | — | — | Leave unchanged |

## 8. SourceLab — generation flows

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| Clinical Scenario builder/result | [source_lab_screen.dart:1979,2185](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:1979) | Acceptable | unread fully | — | P2 | Med | Needs live screenshot |
| Learning Plan builder/result | source_lab_screen.dart:2240, :2449 | Acceptable | unread fully | — | P2 | Med | Needs live screenshot |
| Podcast builder/result | source_lab_screen.dart:2507, :2708 | Acceptable | unread fully | — | P2 | Med | Needs live screenshot |
| Infographic builder/result/loading | source_lab_screen.dart:3755, :3937, :4676 | Good | loading state already patched in `8f91468` with branded header | — | — | — | Leave unchanged |
| Mind Map builder/result/loading | source_lab_screen.dart:3982, :4184, :4313 | Good | loading delegates to `_LabLoadingState` (ProcessingCard) | — | — | — | Leave unchanged |
| Exam Morning Summary loading | [source_lab_screen.dart:3460](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:3460) | Good | already patched in `8f91468` | — | — | — | Leave unchanged |
| `_LabNotice` (amber notice) | [source_lab_screen.dart:5400](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:5400) | Acceptable | uses hardcoded amber colors very close to `AppColors.warning/warningBg`; could swap for tokens for consistency | swap to AppColors tokens | P2 | Low | Patch now |
| `_LabEmptyState` | [source_lab_screen.dart:1539](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:1539) | Good | unread but similar pattern to BaseForce empty | — | — | — | Leave unchanged |

## 9. Central AI

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| Hero card | [central_ai_screen.dart:188](lib/features/central_ai/presentation/screens/central_ai_screen.dart:188) | Excellent | PremiumHeroCard with metrics | — | — | — | Leave unchanged |
| Presets card | [central_ai_screen.dart:221](lib/features/central_ai/presentation/screens/central_ai_screen.dart:221) | Excellent | SourceBaseCard + ActionChips | — | — | — | Leave unchanged |
| Context panel — loading | [central_ai_screen.dart:396-397](lib/features/central_ai/presentation/screens/central_ai_screen.dart:396) | **Weak** | bare 3-px `LinearProgressIndicator` with no caption; user sees a thin moving bar in the middle of the panel with no context | add inline "Drive kaynakları yükleniyor" caption next to the bar | P1 | Low | Patch now |
| Context panel — error | [central_ai_screen.dart:398](lib/features/central_ai/presentation/screens/central_ai_screen.dart:398) | Excellent | `_ContextNotice` with retry | — | — | — | Leave unchanged |
| Context panel — empty | [central_ai_screen.dart:405](lib/features/central_ai/presentation/screens/central_ai_screen.dart:405) | Excellent | folder_off + explanation | — | — | — | Leave unchanged |
| Context file cards | [central_ai_screen.dart:483](lib/features/central_ai/presentation/screens/central_ai_screen.dart:483) | Good | per-file selection + disabled state | — | — | — | Leave unchanged |
| Chat bubble — AI/User | [central_ai_screen.dart:564](lib/features/central_ai/presentation/screens/central_ai_screen.dart:564) | Excellent | premium bubble shape, avatar | — | — | — | Leave unchanged |
| Chat bubble — thinking | [central_ai_screen.dart:646](lib/features/central_ai/presentation/screens/central_ai_screen.dart:646) | Excellent | already patched in `f4b5cd8` | — | — | — | Leave unchanged |
| Composer | [central_ai_screen.dart:760+](lib/features/central_ai/presentation/screens/central_ai_screen.dart:760) | Excellent | viewInsets-aware keyboard handling, gradient send button | — | — | — | Leave unchanged |

## 10. Profile / Store / Settings

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| Profile header | [profile_screen.dart:614](lib/features/profile/presentation/screens/profile_screen.dart:614) | Acceptable | unread fully | — | P2 | Low | Needs live screenshot |
| Wallet panel | [profile_screen.dart:936](lib/features/profile/presentation/screens/profile_screen.dart:936) | Acceptable | unread fully | — | P2 | Low | Needs live screenshot |
| Store package tile | [profile_screen.dart:1212](lib/features/profile/presentation/screens/profile_screen.dart:1212) | Acceptable | uses FilledButton + small CPI spinner during purchase; unread fully | — | P2 | Med | Needs live screenshot |
| Payment state notice | [profile_screen.dart:1550](lib/features/profile/presentation/screens/profile_screen.dart:1550) | Excellent | 5-state tinted (pending/success/failed/cancelled/unknown) | — | — | — | Leave unchanged |
| Profile/Store empty/error states | [profile_screen.dart:1870-1901](lib/features/profile/presentation/screens/profile_screen.dart:1870) | Excellent | wraps SourceBaseEmptyState | — | — | — | Leave unchanged |
| Settings group / items | profile_screen.dart:2005, :2026 | Acceptable | unread fully | — | P2 | Low | Needs live screenshot |

## 11. Generated output readers

| Screen / state | File | Quality | Decision |
|---|---|---|---|
| FlashcardReader, QuestionReader, SummaryReader, FlowReader, TableReader, PodcastReader, InfographicReader, MindMapReader, GenericReader | [generated_output_readers.dart](lib/features/generated_outputs/presentation/widgets/generated_output_readers.dart) | Excellent | Leave unchanged — per-type, calm, academic, fallback `GenericReader` exists |
| `GeneratedOutputEmptyState` / `GeneratedOutputErrorState` | [generated_output_readers.dart:63-101](lib/features/generated_outputs/presentation/widgets/generated_output_readers.dart:63) | Excellent | Leave unchanged |

## Inventory summary

- **Screens / states reviewed by source read:** 60+ concrete entries above
- **Patched in prior sprints (preserved):** 5 (bootstrap loaders, Drive readiness, SourceLab loading headers, Central AI thinking bubble)
- **Patched this sprint:** 4 — see commit list at end of session report (auth CTA hierarchy ×2, uploads progress bar, Central AI context loading caption, `_LabNotice` token swap)
- **Intentionally left unchanged:** 40+ items already at "Excellent" or "Good" — mechanical changes would hurt
- **Needs live screenshot/QA:** 11 items (mostly inside the 8K-line BaseForce/SourceLab screens and the 2K-line Profile screen, where reading every state in source isn't a faithful substitute for actually seeing the rendered UI on a phone)

## Out of scope (per project hard-protection rules)

Backend, auth backend, payment backend, StoreKit/Play billing, Drive ingestion/extraction, Supabase Edge Functions, env, secrets, Docker, Coolify, Qlinik, DB migrations.
