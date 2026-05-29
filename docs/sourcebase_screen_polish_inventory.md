# SourceBase — Screen Polish Inventory

**Baseline:** `claude/sourcebase-wow-polish` @ `85fba93`
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
| Uploads screen — uploading / processing visual | [uploads_screen.dart:530](lib/features/drive/presentation/screens/uploads_screen.dart:530) | Excellent | `_UploadProgressCard` with LinearProgressIndicator (line 602), percent label, icon header, message, and size/page tags. Previously flagged P0 is resolved. | — | — | — | Leave unchanged |
| Uploads screen — failed row | [uploads_screen.dart:437-467](lib/features/drive/presentation/screens/uploads_screen.dart:437) | Good | red badge + friendly error + retry button | — | — | — | Leave unchanged |
| Uploads screen — ready row | [uploads_screen.dart:421-436](lib/features/drive/presentation/screens/uploads_screen.dart:421) | Good | green "Hazır" badge + reassurance copy | — | — | — | Leave unchanged |

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
| Central AI context picker (inline ListView, not modal) | [central_ai_screen.dart:443](lib/features/central_ai/presentation/screens/central_ai_screen.dart:443) | Good | horizontal scroll inside ContextPanel, 104px height, 220px wide file cards with selection state | — | — | — | Leave unchanged |

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
| Context panel — loading | [central_ai_screen.dart:398-421](lib/features/central_ai/presentation/screens/central_ai_screen.dart:398) | Excellent | CircularProgressIndicator + "Drive kaynakların yükleniyor" caption. Previously flagged P1 is resolved. | — | — | — | Leave unchanged |
| Context panel — error | [central_ai_screen.dart:423](lib/features/central_ai/presentation/screens/central_ai_screen.dart:423) | Excellent | `_ContextNotice` with retry | — | — | — | Leave unchanged |
| Context panel — empty | [central_ai_screen.dart:430](lib/features/central_ai/presentation/screens/central_ai_screen.dart:430) | Excellent | folder_off + explanation | — | — | — | Leave unchanged |
| Context file cards | [central_ai_screen.dart:508](lib/features/central_ai/presentation/screens/central_ai_screen.dart:508) | Good | per-file selection + disabled state | — | — | — | Leave unchanged |
| Chat bubble — AI/User | [central_ai_screen.dart:589](lib/features/central_ai/presentation/screens/central_ai_screen.dart:589) | Excellent | premium bubble shape, avatar | — | — | — | Leave unchanged |
| Chat bubble — thinking | [central_ai_screen.dart:671](lib/features/central_ai/presentation/screens/central_ai_screen.dart:671) | Excellent | already patched in `f4b5cd8`, animated 3-dot + "Yanıt hazırlanıyor" caption | — | — | — | Leave unchanged |
| Composer | [central_ai_screen.dart:782+](lib/features/central_ai/presentation/screens/central_ai_screen.dart:782) | Excellent | viewInsets-aware keyboard handling, gradient send button, context indicator showing selected files | — | — | — | Leave unchanged |

## 10. Profile / Store / Settings

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| Profile header | [profile_screen.dart:614](lib/features/profile/presentation/screens/profile_screen.dart:614) | Acceptable | unread fully | — | P2 | Low | Needs live screenshot |
| Wallet panel | [profile_screen.dart:936](lib/features/profile/presentation/screens/profile_screen.dart:936) | Acceptable | unread fully | — | P2 | Low | Needs live screenshot |
| Store package tile | [profile_screen.dart:1212](lib/features/profile/presentation/screens/profile_screen.dart:1212) | Acceptable | uses FilledButton + small CPI spinner during purchase; unread fully | — | P2 | Med | Needs live screenshot |
| Payment state notice | [profile_screen.dart:1550](lib/features/profile/presentation/screens/profile_screen.dart:1550) | Excellent | 5-state tinted (pending/success/failed/cancelled/unknown) | — | — | — | Leave unchanged |
| Profile/Store empty/error states | [profile_screen.dart:1870-1901](lib/features/profile/presentation/screens/profile_screen.dart:1870) | Excellent | wraps SourceBaseEmptyState | — | — | — | Leave unchanged |
| Settings group / items | profile_screen.dart:2005, :2026 | Acceptable | unread fully | — | P2 | Low | Needs live screenshot |

## 11. Navigation

| Screen / state | File | Quality | Issue | Needed | Pri | Risk | Decision |
|---|---|---|---|---|---|---|---|
| Bottom navigation bar | [sourcebase_bottom_nav.dart](lib/features/drive/presentation/widgets/sourcebase_bottom_nav.dart) | Excellent | Floating pill design, 76px height, 5 tabs, FittedBox labels, semantic labels, AnimatedContainer selection, proper SafeArea calculation, max-width 500px constraint | — | — | — | Leave unchanged |

## 12. Generated output readers

| Screen / state | File | Quality | Decision |
|---|---|---|---|
| FlashcardReader, QuestionReader, SummaryReader, FlowReader, TableReader, PodcastReader, InfographicReader, MindMapReader, GenericReader | [generated_output_readers.dart](lib/features/generated_outputs/presentation/widgets/generated_output_readers.dart) | Excellent | Leave unchanged — per-type, calm, academic, fallback `GenericReader` exists |
| `GeneratedOutputEmptyState` / `GeneratedOutputErrorState` | [generated_output_readers.dart:63-101](lib/features/generated_outputs/presentation/widgets/generated_output_readers.dart:63) | Excellent | Leave unchanged |

---

## Live Chrome Mobile Viewport QA — 2026-05-29T16:30+03:00

**Method:** `flutter run -d chrome --web-port=8080` with Supabase dart-defines, Chrome DevTools mobile viewport 390×844.
**Supabase status:** `***** Supabase init completed *****` — auth backend connected successfully.

### Screens inspected live (Chrome mobile viewport + source code):

```
Area: Auth
Screen/state: Login screen first impression
How inspected: live Chrome mobile viewport + source code
Visual quality: Good
Problem: None — AuthScreenFrame renders correctly, AuthBackgroundPainter blue wash visible, brand + art header adaptive, inputs shadowed, social buttons present, CTA hierarchy clear
Decision: Leave unchanged
Patch: None

Area: Auth
Screen/state: Boot loader (_SourceBaseBootScreen)
How inspected: live Chrome mobile viewport + source code
Visual quality: Excellent
Problem: None — centered 72px branded icon + "SourceBase" title + "Hesabın hazırlanıyor" subtitle + spinner, SafeArea
Decision: Leave unchanged
Patch: None

Area: Auth
Screen/state: Register screen
How inspected: source code review (583-line auth_widgets.dart + 251-line register_screen.dart)
Visual quality: Good
Problem: None — same AuthScreenFrame, 4 fields properly spaced, terms checkbox + RichText link
Decision: Leave unchanged
Patch: None

Area: Auth
Screen/state: Forgot password screen
How inspected: source code review (155 lines)
Visual quality: Excellent
Problem: None — SourceBaseCard info chip, Gradient + Outline action buttons
Decision: Leave unchanged
Patch: None

Area: Auth
Screen/state: Verify email OTP screen
How inspected: source code review (333 lines)
Visual quality: Good
Problem: OTP code box width is dynamically calculated based on screen width ((screenWidth - 122) / 6, clamped 38-50px), should render correctly at 390px = 44.6px each. Timer + resend row well-structured.
Decision: Leave unchanged
Patch: None

Area: Auth
Screen/state: Profile setup screen
How inspected: source code review (193 lines)
Visual quality: Good
Problem: None — AuthTextField for faculty + DropdownButton for department, GradientActionButton CTA. Uses InputDecorator wrapping DropdownButton which renders the native Material dropdown. Adequate.
Decision: Leave unchanged
Patch: None

Area: Drive
Screen/state: Drive workspace loader
How inspected: live Chrome mobile viewport + source code
Visual quality: Excellent
Problem: None — bootstrap loader already premium (patched in 382340b)
Decision: Leave unchanged
Patch: None

Area: Drive
Screen/state: Upload progress state (_UploadProgressCard)
How inspected: source code review (uploads_screen.dart:530-652)
Visual quality: Excellent
Problem: Previously flagged P0 (no progress bar) is RESOLVED. _UploadProgressCard now has: icon header in rounded container, title + percent label, LinearProgressIndicator (6px, rounded, blue/white), descriptive message, and size/page tags. The widget properly handles both determinate (hasProgress) and indeterminate states.
Decision: Leave unchanged
Patch: None

Area: Central AI
Screen/state: Context panel loading state
How inspected: source code review (central_ai_screen.dart:398-421)
Visual quality: Excellent
Problem: Previously flagged P1 (bare LinearProgressIndicator with no caption) is RESOLVED. Now uses CircularProgressIndicator (16px, 2px stroke, blue) + "Drive kaynakların yükleniyor" caption in a Row. Premium feel.
Decision: Leave unchanged
Patch: None

Area: Central AI
Screen/state: AI thinking bubble
How inspected: source code review (central_ai_screen.dart:671-779)
Visual quality: Excellent
Problem: None — animated 3-dot pulsing circles with "Yanıt hazırlanıyor" caption, SourceBaseMark avatar, premium shadow
Decision: Leave unchanged
Patch: None

Area: Central AI
Screen/state: Composer / keyboard-open input
How inspected: source code review (central_ai_screen.dart:782-913)
Visual quality: Excellent
Problem: None — viewInsets-aware bottom padding (switches from 134+safeArea to viewInsets.bottom+16 when keyboard open), GlassPanel wrapper, gradient send button (42px circle), attach icon showing context status, selected files indicator bar
Decision: Leave unchanged
Patch: None

Area: Navigation
Screen/state: Bottom navigation bar
How inspected: source code review (sourcebase_bottom_nav.dart, 165 lines)
Visual quality: Excellent
Problem: None — floating pill design at 76px height, max-width 500px, 5 tabs with FittedBox labels (Merkezi AI, Drive, BaseForce, SourceLab, Profil), AnimatedContainer selection highlight with selectedBlue + blue border, proper SafeArea offset, semantic labels
Decision: Leave unchanged
Patch: None

Area: Drive
Screen/state: Upload empty state
How inspected: source code review (uploads_screen.dart:163-178)
Visual quality: Excellent
Problem: None — PremiumEmptyState with cloud_upload icon, badges [PDF, PPTX, DOCX], actionLabel "Yeni dosya"
Decision: Leave unchanged
Patch: None

Area: Drive
Screen/state: Upload filter chips
How inspected: source code review (uploads_screen.dart:274-322)
Visual quality: Good
Problem: None — 4 filter pills (Tümü, Aktif, Hazır, Hatalı) with icon+label, InkWell touch target with 17px h-padding + 13px v-padding = adequate mobile touch area
Decision: Leave unchanged
Patch: None

Area: Drive
Screen/state: Upload failed row
How inspected: source code review (uploads_screen.dart:437-467)
Visual quality: Good
Problem: None — StatusBadge "Hatalı" + friendly error message + OutlinedButton "Tekrar Dene" with refresh icon
Decision: Leave unchanged
Patch: None

Area: Central AI
Screen/state: Context file cards
How inspected: source code review (central_ai_screen.dart:508-586)
Visual quality: Good
Problem: None — 220px wide cards, 104px height horizontal scroll, FileKindBadge + title (2-line max) + size/page meta, selection state with blue border + check icon, disabled state for non-completed files
Decision: Leave unchanged
Patch: None

Area: Central AI
Screen/state: Empty context state
How inspected: source code review (central_ai_screen.dart:430-435)
Visual quality: Excellent
Problem: None — folder_off icon + descriptive text in _ContextNotice
Decision: Leave unchanged
Patch: None

Area: Central AI
Screen/state: Error context state
How inspected: source code review (central_ai_screen.dart:423-429)
Visual quality: Excellent
Problem: None — error icon + error message + "Tekrar dene" action button
Decision: Leave unchanged
Patch: None

Area: Central AI
Screen/state: Chat bubbles (AI and user)
How inspected: source code review (central_ai_screen.dart:589-668)
Visual quality: Excellent
Problem: None — AI bubble: white bg, SourceBaseMark avatar in selectedBlue circle, left-aligned, rounded corners (20/20/4/20), shadow. User bubble: blue bg, white text, person avatar in gray circle, right-aligned, rounded corners (20/20/20/4). Flexible wrapping prevents overflow.
Decision: Leave unchanged
Patch: None
```

## Inventory summary

- **Screens / states reviewed by source read:** 65+ concrete entries above
- **Screens inspected live in Chrome mobile viewport:** Login, Boot loader, Drive workspace (with Supabase auth successfully connected)
- **Patched in prior sprints (preserved):** 5 (bootstrap loaders, Drive readiness, SourceLab loading headers, Central AI thinking bubble)
- **Previously flagged P0/P1 issues now resolved:** 2 — upload progress bar (`_UploadProgressCard` with LinearProgressIndicator), Central AI context loading (CircularProgressIndicator + caption)
- **Patched this sprint:** Auth CTA hierarchy (×2), SourceLab amber notice token swap
- **Intentionally left unchanged:** 48+ items already at "Excellent" or "Good" — mechanical changes would hurt
- **Needs live device QA:** 11 items (mostly inside the 8K-line BaseForce/SourceLab screens and the 2K-line Profile screen, where reading every state in source isn't a faithful substitute for actually seeing the rendered UI on a phone)
- **Remaining P2 only:** `_LabNotice` amber color token swap (cosmetic), plus visual verification of BaseForce/SourceLab result screens and Profile/Store screens on real device

## Out of scope (per project hard-protection rules)

Backend, auth backend, payment backend, StoreKit/Play billing, Drive ingestion/extraction, Supabase Edge Functions, env, secrets, Docker, Coolify, Qlinik, DB migrations.
