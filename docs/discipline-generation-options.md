# Discipline-Tailored Generation Options

How SourceBase should tailor the **menu, ordering, and labeling** of content-generation
tools per academic discipline (Veterinerlik, Tıp, Diş Hekimliği, Hemşirelik, Ebelik).

> Key insight from the codebase: discipline **already** influences generated *content*
> (the student persona is prepended to every AI request via `studentContext`). What is
> missing is per-discipline differentiation of the **option menu** — which tools are
> surfaced, in what order, with what Turkish labels and exam vocabulary. All five
> disciplines currently see the identical, medicine-centric tool grid.

---

## 1. Current generation kinds inventory (from codebase)

### Source of truth: `GeneratedKind`

`SourceBaseBackend/Sources/SourceBaseBackend/Drive/DriveModels.swift:64`

```swift
public enum GeneratedKind: String, Codable, Sendable, CaseIterable {
    case flashcard, question, summary, algorithm, comparison
    case examMorningSummary = "exam_morning_summary"
    case clinicalScenario = "clinical_scenario"
    case learningPlan = "learning_plan"
    case podcast, table, infographic
    case mindMap = "mindMap"
}
```

`titleLabel`, `jobType`, and `defaultCount` are all defined on the enum
(`DriveModels.swift:72-112`). Note `comparison` and `table` collapse to the same
`jobType` ("comparison").

| Kind (`GeneratedKind`) | `jobType` | `titleLabel` (current Turkish) | What it produces |
|---|---|---|---|
| `flashcard` | `flashcard` | Flashcard Seti | Atomic active-recall cards (front/back/hint/explanation/concept_group). Default 20. |
| `question` | `quiz` | Soru Seti | 5-option single-answer MCQs ("Qlinik" compatible) with per-option rationales. Default 10. |
| `summary` | `summary` | Özet | High-yield study pack: high_yield_points, must_know, commonly_confused, red_flags, mini_table, self_check, spaced-review prompts. |
| `examMorningSummary` | `exam_morning_summary` | Sınav Sabahı Özeti | Same structured pack, framed as a fast "7-minute" pre-exam critical sweep. |
| `algorithm` | `algorithm` | Algoritma | Mobile decision board: starting_point, decision_nodes, action_steps, critical_thresholds, red_flags, exam_tips. |
| `comparison` | `comparison` | Karşılaştırma | Full-source comparison matrix (criteria rows, distinguishing tips, exam traps, source refs). >= 8 criteria. |
| `table` | `comparison` | Tablo | UI alias of comparison (same backend job). |
| `clinicalScenario` | `clinical_scenario` | Klinik Senaryo | Case: patientInfo, history, exam, labs, problem representation, differential, justification, red flags, teaching points. |
| `learningPlan` | `learning_plan` | Öğrenme Planı | Day-segmented study plan: sessions, dailyGoals, reviewDays (today/24h/72h/7d), weakPoints, objectives. |
| `podcast` | `podcast` | Podcast | Longform audio (m4a/mp3) + segmented transcript + recap + active-recall prompts. |
| `infographic` | `infographic` | İnfografik | Shareable visual (image_url) + sections/bullets + warnings + quick_check; text-block fallback. |
| `mindMap` | `mind_map` | Zihin Haritası | centralTopic, branches, criticalConnections, commonly_confused, clinicalTusTips. |

### How the two home screens present/group them

**`BaseForceHomeView`** — `SourceBaseiOS/.../Features/BaseForce/BaseForceHomeView.swift`
- The grid is a **hardcoded** `[ProductionTool]` array in two computed groups:
  - `mainTools` (`BaseForceHomeView.swift:145`): Flashcard, Soru, "Son tekrar" (=summary), Akış (=algorithm), Tablo (=comparison), plus the Üretim Kuyruğu entry.
  - `deepTools` (`BaseForceHomeView.swift:156`): Klinik Senaryo, Sınav Sabahı, Öğrenme Planı, Podcast, İnfografik, Zihin Haritası.
- `ProductionTool` struct: `BaseForceHomeView.swift:342`. Each carries `icon/title/subtitle/color/route/isDeepTool`. Tools route to `AppRoute` cases (`.flashcardFactory`, `.questionFactory`, `.summaryFactory`, `.algorithmFactory`, `.comparisonFactory`, and deep routes `.clinical/.examMorning/.plan/.podcast/.infographic/.mindMap`).
- Group section rendered by `productionToolsSection` / `toolGroup` (`BaseForceHomeView.swift:110-143`).
- Hero copy is hardcoded medicine-flavored: `heroSection` (`BaseForceHomeView.swift:65`) — "Flashcard, soru, özet, akış, tablo ve klinik tekrarları tek yerden başlat."

**`SourceLabHomeView`** — `SourceBaseiOS/.../Features/SourceLab/SourceLabHomeView.swift`
- A hardcoded `private let tools: [Tool]` array (`SourceLabHomeView.swift:20`) of the 6 deep kinds keyed by `GeneratedKind`: examMorningSummary, clinicalScenario, learningPlan, podcast, infographic, mindMap.
- `Tool` struct + `route` switch: `SourceLabHomeView.swift:163-181`.

**Per-kind generation contract** (already richly defined, discipline-agnostic):
`SourceBaseiOS/.../Features/BaseForce/SourceBaseGenerationContract.swift` —
`aiBrief(for:mode:sourceLabel:)` (`:405`) is **hardcoded to "Tıp öğrencisi ihtiyacı…"**
(`:411`). This is a second place where medicine is baked in and should consume the
discipline profile.

The per-kind factory views (`FlashcardFactoryView`, `QuestionFactoryView`,
`SummaryFactoryView`, `AlgorithmFactoryView`, `ComparisonFactoryView`) and deep views
(`ClinicalView`, `ExamMorningView`, `PlanView`, `PodcastView`, `InfographicView`,
`MindMapView`) are the per-tool screens reached from those routes.

---

## 2. Current discipline/goal capture & injection points

| Concern | File / symbol |
|---|---|
| Discipline + goal **capture UI** | `SourceBaseiOS/.../Features/Auth/ProfileSetupView.swift` — `@State department` (default "Tıp"), `classYear`, `goal`; `departments = ["Veterinerlik","Tıp","Diş Hekimliği","Hemşirelik","Ebelik"]` (`:14`); `classYears` 1–6 + Mezun (`:15`); **discipline-aware goals already exist** in `goals(for:)` (`:18-26`). |
| Save path | `ProfileSetupView.completeProfile()` (`:286`) → `session.updateProfile(faculty:department:classYear:goal:)`. |
| Profile model | `SourceBaseBackend/.../Auth/AuthModels.swift:37` — `struct SourceBaseProfile { faculty, department, classYear, goal }`. |
| **Persona injected into AI** | `SourceBaseProfile.studentContext` (`AuthModels.swift:70`) → `"\(department) · \(classYear) · hedef: \(goal) · \(faculty)"`. |
| **Injection point into generation** | `SourceBaseiOS/.../Core/SourceBaseWorkspaceStore.swift:600` — inside `enqueueDriveGeneration`, `studentContext` is added to `enrichedOptions["studentContext"]` / `["student_context"]` and sent to `repository().startGenerationJob`. The server `personalize()` step prepends it to the system prompt. |
| Metadata keys (Supabase) | `sourcebase_department`, `sourcebase_class_year`, `sourcebase_goal`, `sourcebase_faculty` (`AuthBackend.swift`, `AuthModels.metadata()`). |
| Read-back of profile | `AuthBackend.currentProfile()` (used at `SourceBaseWorkspaceStore.swift:600`); also `ProfileRepository`. |

**Takeaway:** the discipline string is available app-wide via
`AuthBackend.shared.currentProfile()?.department`. The home screens do **not** read it
today; they render fixed arrays. The implementation in §4 introduces a
`disciplineOptionProfile(for:)` that the home screens consume.

`goals(for:)` already encodes the right exam vocabulary per discipline — reuse/centralize
it rather than reinventing.

---

## 3. Per-discipline recommended option menu

Notation: kinds in **priority order** (first = most surfaced). "New preset" = a relabeled
or specialized wrapper over an existing `GeneratedKind` (no new backend kind required —
it differs only in label/subtitle/seed-prompt). Exam-goal terms feed both the
ProfileSetup `goals(for:)` list and the AI persona.

### Tıp (Medicine)
- **Primary kinds (order):** `question` → `clinicalScenario` → `summary`/`examMorningSummary` → `algorithm` → `comparison` → `flashcard` → `mindMap` → `infographic` → `podcast` → `learningPlan`.
- **Why:** TUS is 2×100 MCQ (Temel + Klinik Bilimler); clinical years lean on vaka + algoritma + yüksek-getirili özet. This is the current default — keep it as the baseline profile.
- **New presets / relabels:**
  - "TUS Soru Kampı" (question, framed for TUS MCQ traps) — show for goal=TUS.
  - "Vaka" (clinicalScenario) — already strong; surface earlier in clinical years (classYear 4-6/Mezun).
  - "Yüksek Getirili Özet" (summary relabel) for TUS goal.
- **Exam-goal terms:** Dönem sınavları, **TUS**, **USMLE**, Genel tekrar (already in `goals(for:)`).

### Diş Hekimliği (Dentistry)
- **Primary kinds (order):** `question` → `comparison` → `summary` → `flashcard` → `algorithm` → `clinicalScenario` → `mindMap` → `infographic` → `examMorningSummary` → `podcast` → `learningPlan`.
- **Why:** DUS = 120 MCQ (40 Temel + 80 Klinik). Clinical sciences are 8 × 10-question branches (Protetik, Restoratif, Ağız-Diş-Çene Cerrahisi, Radyoloji, Periodontoloji, Endodonti, Ortodonti, Pedodonti). Comparison tables fit branch-by-branch material (sınıflama, materyal seçimi).
- **New presets / relabels:**
  - "DUS Yüksek Getirili" (summary preset) — high-yield per branş.
  - "DUS Soru Kampı" (question preset, 5-choice) for goal=DUS.
  - "Klinik Vaka (Diş)" (clinicalScenario relabel) — restoratif/endo/cerrahi case framing.
  - Comparison surfaced high (e.g. "Materyal/Sınıflama Karşılaştırması" — Black sınıflandırması, kompozit vs amalgam, sabit vs hareketli protez).
- **Exam-goal terms:** Dönem sınavları, **DUS**, Genel tekrar (already in `goals(for:)`).

### Hemşirelik (Nursing) — **NO TUS**
- **Primary kinds (order):** `summary` → `flashcard` → `algorithm` → `question` → `comparison` → `clinicalScenario` → `learningPlan` → `mindMap` → `infographic` → `examMorningSummary` → `podcast`.
- **Why:** Career exam is **KPSS** (general ability/culture, no field test) → KPSS framing should NOT pull medical MCQ tooling to the top. The day-to-day study artifacts are **bakım planı (NANDA-I / NIC / NOC)**, **ilaç dozu/hesaplama**, **vital bulgu takibi**, and **klinik uygulama**. Algorithm fits care-decision flows; comparison fits NANDA-NIC-NOC matrices.
- **New presets / relabels (highest value adds in the whole project):**
  - **"Bakım Planı (NANDA / NIC / NOC)"** — a *new preset* over `comparison` (or a structured `summary`): tanı → girişim → çıktı matrix. This is the signature nursing artifact and is absent today.
  - **"İlaç Doz Hesabı"** — preset over `algorithm`/`question`: dose calculation steps + practice problems (mg/kg, damla/dakika, infüzyon hızı).
  - **"Vital Takip Kartı"** — preset over `flashcard`/`summary`: normal ranges + red-flag thresholds.
  - "Klinik Uygulama Senaryosu" (clinicalScenario relabel — bakım-odaklı, not differential-diagnosis-heavy).
- **Exam-goal terms:** Dönem sınavları, **KPSS/atama**, **Klinik pratik**, **İntibak**, Genel tekrar. (`goals(for:)` currently has KPSS/atama, Klinik pratik — **add "İntibak"**.)

### Ebelik (Midwifery)
- **Primary kinds (order):** `algorithm` → `summary` → `flashcard` → `clinicalScenario` → `comparison` → `question` → `learningPlan` → `mindMap` → `infographic` → `examMorningSummary` → `podcast`.
- **Why:** Also KPSS (no field test). Core competencies are **gebelik takibi (antenatal)**, **doğum eylemi evreleri**, **partograf**, **postpartum/lohusa bakımı**, **neonatal bakım**. Stage-based and partograph content is inherently flow/decision-shaped → algorithm leads.
- **New presets / relabels:**
  - **"Partograf / Doğum Eylemi Kartı"** — preset over `algorithm`: evre 1-2-3-4, servikal dilatasyon, fetal/maternal izlem decision board.
  - **"Antenatal İzlem Planı"** — preset over `learningPlan`/`summary`: trimester-by-trimester takip.
  - **"Neonatal Bakım Özeti"** — preset over `summary`: APGAR, ısı/beslenme, riskli yenidoğan.
  - "Gebelik/Doğum Vakası" (clinicalScenario relabel — obstetric/midwifery framing).
- **Exam-goal terms:** Dönem sınavları, **KPSS/atama**, **Klinik pratik**, Genel tekrar (shares nursing list).

### Veterinerlik (Veterinary)
- **Primary kinds (order):** `comparison` → `clinicalScenario` → `summary` → `flashcard` → `algorithm` → `question` → `mindMap` → `infographic` → `learningPlan` → `examMorningSummary` → `podcast`.
- **Why:** Strongly **species-based** (büyükbaş / küçükbaş / kanatlı / egzotik) → comparison/"Tür Karşılaştırma" is the standout tool (dose, anatomy, disease presentation differ per species). Uzmanlık sınavı is theoretical + practical; saha pratiği rewards case + decision-flow + zoonosis red-flags.
- **New presets / relabels:**
  - **"Tür Karşılaştırma"** — preset over `comparison`: same criterion across species (büyükbaş vs küçükbaş vs kanatlı vs egzotik) — doz, semptom, anatomi.
  - **"Saha Vakası"** — preset over `clinicalScenario`: field-practice framing, species-specific.
  - **"Zoonoz Kırmızı Bayrak"** — preset over `algorithm`/`summary`: zoonosis recognition + handling.
  - "Uzmanlık Soru Kampı" (question preset) for goal=Uzmanlık/alan sınavı.
- **Exam-goal terms:** Dönem sınavları, **Uzmanlık/alan sınavı**, **Saha pratiği**, Genel tekrar (already in `goals(for:)`).

### Summary matrix (top 4 per discipline)

| Discipline | #1 | #2 | #3 | #4 | Signature new preset |
|---|---|---|---|---|---|
| **Tıp** | Soru (question) | Klinik Senaryo | Özet/Sınav Sabahı | Algoritma | TUS Soru Kampı |
| **Diş Hekimliği** | Soru (DUS) | Tablo/Karşılaştırma | Özet | Flashcard | DUS Yüksek Getirili |
| **Hemşirelik** | Özet | Flashcard | Algoritma | Soru | **Bakım Planı (NANDA/NIC/NOC)** |
| **Ebelik** | Algoritma | Özet | Flashcard | Klinik Senaryo | **Partograf / Doğum Eylemi Kartı** |
| **Veterinerlik** | Karşılaştırma | Klinik Senaryo (Saha) | Özet | Flashcard | **Tür Karşılaştırma** |

---

## 4. Concrete implementation proposal

Goal: a single, data-driven mapping the home screens consume to **filter + reorder +
relabel** the tool grid, plus optional discipline presets. No new backend `GeneratedKind`
needed — presets are label/subtitle/seed-prompt wrappers over existing kinds.

### 4.1 New type: `DisciplineOptionProfile`

Create `SourceBaseiOS/Sources/SourceBaseiOS/Features/BaseForce/DisciplineOptionProfile.swift`
(new file). It is pure data + a `static func disciplineOptionProfile(for:)` factory so it is
trivially testable and shared by both home screens and (later) the AI brief.

```swift
import SourceBaseBackend

/// One generation entry to render in a home grid.
struct DisciplineTool: Identifiable {
    let kind: GeneratedKind
    let title: String        // discipline-tuned label, falls back to kind.titleLabel
    let subtitle: String
    let icon: String
    let isDeepTool: Bool      // routes via openDeepTool vs openFactory
    var id: String { title }  // presets over the same kind must stay distinct
}

/// Per-discipline ordered menu + framing. Consumed by BaseForceHomeView /
/// SourceLabHomeView to reorder, hide, and relabel the fixed tool arrays.
struct DisciplineOptionProfile {
    let discipline: String            // matches SourceBaseProfile.department
    let heroSubtitle: String          // replaces hardcoded BaseForceHomeView hero copy
    let mainTools: [DisciplineTool]   // ordered
    let deepTools: [DisciplineTool]   // ordered
    /// Extra free-text appended to studentContext for the AI persona, e.g.
    /// "Hemşirelik öğrencisi: bakım planı (NANDA/NIC/NOC), ilaç dozu, vital takip odaklı."
    let aiPersonaHint: String

    static func disciplineOptionProfile(for department: String) -> DisciplineOptionProfile {
        switch department {
        case "Tıp":            return .tip
        case "Diş Hekimliği":  return .dishekimligi
        case "Hemşirelik":     return .hemsirelik
        case "Ebelik":         return .ebelik
        case "Veterinerlik":   return .veterinerlik
        default:               return .tip   // safe medicine-centric default
        }
    }
}
```

Each static profile (`.tip`, `.hemsirelik`, …) encodes the §3 ordering + labels + presets.
Presets reuse an existing `kind` but override `title`/`subtitle` (e.g.
`DisciplineTool(kind: .comparison, title: "Bakım Planı (NANDA/NIC/NOC)", subtitle: "Tanı · Girişim · Çıktı", icon: "list.bullet.clipboard", isDeepTool: false)`).

### 4.2 Wire into the home screens

- **`BaseForceHomeView.swift`** (`:145` `mainTools`, `:156` `deepTools`, `:65` `heroSection`):
  - Read department: `private var department: String { AuthBackend.shared.currentProfileCached?.department ?? "Tıp" }` (or thread it through `AppState`/`SourceBaseWorkspaceStore` so it's synchronous — see 4.4).
  - Replace the two hardcoded arrays with
    `DisciplineOptionProfile.disciplineOptionProfile(for: department).mainTools/.deepTools`,
    mapping `DisciplineTool` → existing `ProductionTool` (keep the route lookup).
  - Replace hero copy with `profile.heroSubtitle`.
  - Map `kind` → `AppRoute` with a small helper (the route switch already exists in `SourceLabHomeView.Tool.route`; centralize it as `GeneratedKind.factoryRoute`/`.deepRoute`).
- **`SourceLabHomeView.swift`** (`:20` `tools`): replace the fixed array with
  `profile.deepTools` (it already keys on `GeneratedKind`).

### 4.3 Centralize exam-goal vocabulary (remove duplication)

Move `ProfileSetupView.goals(for:)` (`:18`) onto the backend profile so both ProfileSetup
and the AI persona use one source. Suggested home:
`SourceBaseBackend/.../Auth/AuthModels.swift` next to `SourceBaseProfile`:

```swift
public extension SourceBaseProfile {
    static func goals(for department: String) -> [String] { /* moved from ProfileSetupView */ }
}
```

Then in `ProfileSetupView` call `SourceBaseProfile.goals(for: department)`.
**Add "İntibak"** to the Hemşirelik/Ebelik goal list while doing this.

### 4.4 Feed discipline framing into the AI brief

`SourceBaseGenerationContract.aiBrief(for:mode:sourceLabel:)`
(`SourceBaseGenerationContract.swift:405`) hardcodes "Tıp öğrencisi ihtiyacı açık: …"
(`:411`). Thread the discipline through so the brief mirrors the menu framing:

- Easiest path: the persona is already injected server-side via
  `enrichedOptions["studentContext"]` (`SourceBaseWorkspaceStore.swift:600`). Append
  `DisciplineOptionProfile.aiPersonaHint` there too, e.g.:
  ```swift
  if let dept = await AuthBackend.shared.currentProfile()?.department {
      enrichedOptions["disciplineHint"] =
          DisciplineOptionProfile.disciplineOptionProfile(for: dept).aiPersonaHint
  }
  ```
- Optionally generalize the hardcoded sentence in `aiBrief` to be discipline-neutral (it's
  client-side preflight copy, not the final prompt, but it leaks "Tıp" framing).

### 4.5 Files / types to touch (checklist)

| File | Change |
|---|---|
| **NEW** `…/Features/BaseForce/DisciplineOptionProfile.swift` | `DisciplineTool`, `DisciplineOptionProfile`, `disciplineOptionProfile(for:)`, 5 static profiles. |
| `…/Features/BaseForce/BaseForceHomeView.swift` | Consume profile for `mainTools`/`deepTools`/`heroSection`; add `kind → AppRoute` mapping. |
| `…/Features/SourceLab/SourceLabHomeView.swift` | Replace fixed `tools` with `profile.deepTools`. |
| `…/Core/SourceBaseWorkspaceStore.swift` (`:600`) | Append `disciplineHint` to `enrichedOptions`. |
| `SourceBaseBackend/.../Drive/DriveModels.swift` (`GeneratedKind`) | Add `factoryRoute`/`deepRoute` helpers (optional, removes duplicated route switches). |
| `SourceBaseBackend/.../Auth/AuthModels.swift` | Move `goals(for:)`; add "İntibak" to nursing/midwifery. |
| `…/Features/Auth/ProfileSetupView.swift` (`:18`) | Call centralized `SourceBaseProfile.goals(for:)`. |
| `…/Features/BaseForce/SourceBaseGenerationContract.swift` (`:411`) | Make hardcoded "Tıp öğrencisi" framing discipline-aware/neutral. |

This keeps the change additive: existing routes, factory views, the generation contract,
and backend kinds are untouched in shape; only the **menu surface** and a single persona
string become discipline-driven.

---

## Sources

- TUS yapısı / konu dağılımı: [tuskocu.com](https://tuskocu.com/tus-konulari-ve-soru-dagilimi/), [tusdata.com](https://www.tusdata.com/bilgilendirme/tus-konu-dagilimi-hangi-konulardan-ne-kadar-soru-gelecek-haberi-3525), [tustime.com](https://tustime.com/genel/tus-klinik-bilimler-dersleri-ve-konu-icerikleri-nelerdir/)
- DUS yapısı / branş dağılımı: [rehberpanda.com](https://rehberpanda.com/rehberler/dus/konu-dagilimi/), [dustime.com](https://dustime.com/blog/dus-dis-hekimliginde-uzmanlik-egitimi-giris-sinavi/), [enkapsamlibilgiler.com.tr](https://enkapsamlibilgiler.com.tr/egitim/dus-ta-hangi-sorular-cikiyor)
- Hemşirelik bakım planı (NANDA/NIC/NOC) & ilaç/vital: [busbid.baskent.edu.tr](http://busbid.baskent.edu.tr/index.php/busbid/article/view/57), [turkiyeklinikleri.com](https://www.turkiyeklinikleri.com/article/en-iskemik-inme-geciren-bireyin-nanda-iya-gore-hemsirelik-tanilari-nic-hemsirelik-girisimleri-ve-noc-ciktilari-88541.html), [bezmialem.edu.tr (klinik bakım planı rehberi)](https://bezmialem.edu.tr/tr/Documents/ic-hastaliklari-hemsireligi-klinik-bakim-plani-uygulama-hazirlama-rehberi-04-03-2026.pdf)
- Hemşirelik KPSS (alan bilgisi yok): [hemsireyiz.net](https://hemsireyiz.net/hemsirelik-kpss-rehberi-puan-turleri-atama-tabanlari-ve-tum-detaylar-2025/), [basarisiralamalari.com](https://www.basarisiralamalari.com/hemsire-atamalari-kpss-taban-puanlari-lisans/)
- Ebelik: partograf / doğum eylemi / antenatal-postpartum: [akademisyenonline.com (partograf)](https://akademisyenonline.com/index.jsp?kitap_id=26073&mod=bolum_detay), [ogu.edu.tr doğum-travay izlem defteri (PDF)](https://sbf.ogu.edu.tr/Storage/Esyo/Uploads/do%C4%9Fum-travay-izlem-defteri.pdf), [ege.edu.tr Ebelik lisans](https://ebp.ege.edu.tr/DereceProgramlari/Detay/1/61030/8141/932001)
- Veterinerlik uzmanlık & tür-bazlı/zoonoz: [lexpera.com.tr (uzmanlık yönetmeliği)](https://www.lexpera.com.tr/mevzuat/yonetmelikler/tarim-ve-koyisleri-bakanligi-veteriner-hekimligi-uzmanlik-yonetmeligi-1), [istebudoktor.com.tr](https://istebudoktor.com.tr/veteriner-hekim-olmak-icin-hangi-bolum-okunmali), [hacettepelilerakademi.com (büyükbaş vaka)](https://hacettepelilerakademi.com/egitim-buyukbas-veteriner-hekimligi-vaka-snf)
