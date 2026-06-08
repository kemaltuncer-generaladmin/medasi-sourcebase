import SwiftUI
import SourceBaseBackend

/// One generation entry to render in a home grid, with a discipline-tuned
/// label/subtitle. The underlying `GeneratedKind` (and therefore the backend
/// job + factory screen) is unchanged — only the framing differs.
struct DisciplineTool: Identifiable {
    let kind: GeneratedKind
    let title: String
    let subtitle: String
    let icon: String

    var id: String { "\(kind.rawValue)-\(title)" }
}

/// Per-discipline ordered menu + framing for the production home screens.
///
/// The app serves five health-science disciplines (Veterinerlik, Tıp, Diş
/// Hekimliği, Hemşirelik, Ebelik). Discipline already steers generated *content*
/// (the student persona is injected into every AI request); this type adds the
/// missing piece — which tools are surfaced, in what order, with what Turkish
/// labels — so e.g. a nursing student is not pushed TUS-shaped tooling first.
///
/// Presets (e.g. "Bakım Planı (NANDA/NIC/NOC)", "Partograf / Doğum Eylemi",
/// "Tür Karşılaştırma") are relabels over the best-fit existing kind — no new
/// backend `GeneratedKind` is required. The `aiPersonaHint` is appended to the
/// generation options so the produced content matches the menu's framing.
struct DisciplineOptionProfile {
    let heroSubtitle: String
    let mainKinds: [DisciplineTool]
    let deepKinds: [DisciplineTool]
    let aiPersonaHint: String

    static func profile(for department: String?) -> DisciplineOptionProfile {
        switch (department ?? "").trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Diş Hekimliği":  return .dishekimligi
        case "Hemşirelik":     return .hemsirelik
        case "Ebelik":         return .ebelik
        case "Veterinerlik":   return .veterinerlik
        case "Tıp":            return .tip
        default:               return .tip   // safe, medicine-centric default
        }
    }

    // MARK: - Tıp (default / baseline)

    static let tip = DisciplineOptionProfile(
        heroSubtitle: "Flashcard, soru, özet, akış, tablo ve klinik tekrarları tek yerden başlat.",
        mainKinds: [
            DisciplineTool(kind: .question, title: "Soru", subtitle: "TUS tarzı soru pratiği", icon: "questionmark.circle"),
            DisciplineTool(kind: .summary, title: "Yüksek Getirili Özet", subtitle: "Kısa ve net tekrar", icon: "doc.text"),
            DisciplineTool(kind: .algorithm, title: "Akış", subtitle: "Karar adımlarını sadeleştir", icon: "arrow.triangle.branch"),
            DisciplineTool(kind: .comparison, title: "Karşılaştırma", subtitle: "Konuları yan yana kıyasla", icon: "tablecells"),
            DisciplineTool(kind: .flashcard, title: "Flashcard", subtitle: "Tekrar kartları", icon: "rectangle.on.rectangle")
        ],
        deepKinds: [
            DisciplineTool(kind: .clinicalScenario, title: "Klinik Senaryo", subtitle: "Ayırıcı tanı pratiği", icon: "cross.case"),
            DisciplineTool(kind: .examMorningSummary, title: "Sınav Sabahı", subtitle: "7 dakikalık kritik tarama", icon: "bolt"),
            DisciplineTool(kind: .learningPlan, title: "Öğrenme Planı", subtitle: "Bugün, 72 saat, 7 gün", icon: "checklist"),
            DisciplineTool(kind: .mindMap, title: "Zihin Haritası", subtitle: "Kavram ilişkilerini ayır", icon: "point.3.connected.trianglepath.dotted"),
            DisciplineTool(kind: .infographic, title: "İnfografik", subtitle: "Tek bakışlık görsel hafıza", icon: "chart.bar.doc.horizontal"),
            DisciplineTool(kind: .podcast, title: "Podcast", subtitle: "Dinlenebilir tekrar", icon: "mic")
        ],
        aiPersonaHint: "Tıp öğrencisi: TUS/USMLE tarzı; vaka, algoritma ve yüksek getirili klinik bilgi odaklı."
    )

    // MARK: - Diş Hekimliği

    static let dishekimligi = DisciplineOptionProfile(
        heroSubtitle: "DUS odaklı çalış: soru kampı, branş karşılaştırmaları ve yüksek getirili özetler.",
        mainKinds: [
            DisciplineTool(kind: .question, title: "DUS Soru Kampı", subtitle: "5 şıklı klinik soru", icon: "questionmark.circle"),
            DisciplineTool(kind: .comparison, title: "Materyal / Sınıflama", subtitle: "Branş bazlı karşılaştırma", icon: "tablecells"),
            DisciplineTool(kind: .summary, title: "DUS Yüksek Getirili", subtitle: "Branş branş özet", icon: "doc.text"),
            DisciplineTool(kind: .flashcard, title: "Flashcard", subtitle: "Tekrar kartları", icon: "rectangle.on.rectangle"),
            DisciplineTool(kind: .algorithm, title: "Tedavi Akışı", subtitle: "Klinik karar adımları", icon: "arrow.triangle.branch")
        ],
        deepKinds: [
            DisciplineTool(kind: .clinicalScenario, title: "Klinik Vaka (Diş)", subtitle: "Restoratif · endo · cerrahi", icon: "cross.case"),
            DisciplineTool(kind: .examMorningSummary, title: "Sınav Sabahı", subtitle: "Kritik tarama", icon: "bolt"),
            DisciplineTool(kind: .mindMap, title: "Zihin Haritası", subtitle: "Kavram ilişkileri", icon: "point.3.connected.trianglepath.dotted"),
            DisciplineTool(kind: .learningPlan, title: "Öğrenme Planı", subtitle: "Günlere bölünmüş", icon: "checklist"),
            DisciplineTool(kind: .infographic, title: "İnfografik", subtitle: "Görsel hafıza", icon: "chart.bar.doc.horizontal"),
            DisciplineTool(kind: .podcast, title: "Podcast", subtitle: "Dinlenebilir tekrar", icon: "mic")
        ],
        aiPersonaHint: "Diş hekimliği öğrencisi: DUS tarzı; ağız-diş-çene klinik branşları (restoratif, endodonti, protetik, cerrahi, periodontoloji, ortodonti, pedodonti, radyoloji) odaklı."
    )

    // MARK: - Hemşirelik (NO TUS)

    static let hemsirelik = DisciplineOptionProfile(
        heroSubtitle: "Bakım planı, ilaç dozu ve klinik uygulama odaklı çalış — TUS değil, KPSS ve klinik pratiğe göre.",
        mainKinds: [
            DisciplineTool(kind: .summary, title: "Yüksek Getirili Özet", subtitle: "Sınav ve kliniğe hızlı tekrar", icon: "doc.text"),
            DisciplineTool(kind: .comparison, title: "Bakım Planı (NANDA/NIC/NOC)", subtitle: "Tanı · Girişim · Çıktı", icon: "list.bullet.clipboard"),
            DisciplineTool(kind: .algorithm, title: "Bakım Akışı / İlaç Dozu", subtitle: "Karar ve doz hesabı adımları", icon: "arrow.triangle.branch"),
            DisciplineTool(kind: .flashcard, title: "Flashcard", subtitle: "Vital değer, ilaç, tanı kartları", icon: "rectangle.on.rectangle"),
            DisciplineTool(kind: .question, title: "Soru", subtitle: "KPSS ve klinik soru pratiği", icon: "questionmark.circle")
        ],
        deepKinds: [
            DisciplineTool(kind: .clinicalScenario, title: "Klinik Uygulama Senaryosu", subtitle: "Bakım odaklı vaka", icon: "cross.case"),
            DisciplineTool(kind: .learningPlan, title: "Öğrenme Planı", subtitle: "Günlere bölünmüş", icon: "checklist"),
            DisciplineTool(kind: .mindMap, title: "Zihin Haritası", subtitle: "Kavram ilişkileri", icon: "point.3.connected.trianglepath.dotted"),
            DisciplineTool(kind: .examMorningSummary, title: "Sınav Sabahı", subtitle: "Kritik tarama", icon: "bolt"),
            DisciplineTool(kind: .infographic, title: "İnfografik", subtitle: "Görsel hafıza", icon: "chart.bar.doc.horizontal"),
            DisciplineTool(kind: .podcast, title: "Podcast", subtitle: "Dinlenebilir tekrar", icon: "mic")
        ],
        aiPersonaHint: "Hemşirelik öğrencisi: insan hekimliği teşhis ağırlığı YERİNE hemşirelik bakım süreci — bakım planı (NANDA/NIC/NOC: tanı, girişim, çıktı), ilaç dozu/hesaplama (mg/kg, damla/dk, infüzyon hızı), vital takip ve klinik uygulama odaklı. Sınav hedefi TUS değil KPSS/klinik pratik."
    )

    // MARK: - Ebelik

    static let ebelik = DisciplineOptionProfile(
        heroSubtitle: "Gebelik takibi, doğum eylemi ve partograf odaklı çalış — KPSS ve klinik pratik için.",
        mainKinds: [
            DisciplineTool(kind: .algorithm, title: "Partograf / Doğum Eylemi", subtitle: "Evre 1-2-3-4 karar tahtası", icon: "arrow.triangle.branch"),
            DisciplineTool(kind: .summary, title: "Antenatal / Neonatal Özet", subtitle: "Trimester ve yenidoğan", icon: "doc.text"),
            DisciplineTool(kind: .flashcard, title: "Flashcard", subtitle: "Tekrar kartları", icon: "rectangle.on.rectangle"),
            DisciplineTool(kind: .comparison, title: "Karşılaştırma", subtitle: "Evre / izlem kıyaslama", icon: "tablecells"),
            DisciplineTool(kind: .question, title: "Soru", subtitle: "KPSS ve klinik soru pratiği", icon: "questionmark.circle")
        ],
        deepKinds: [
            DisciplineTool(kind: .clinicalScenario, title: "Gebelik / Doğum Vakası", subtitle: "Obstetrik senaryo", icon: "cross.case"),
            DisciplineTool(kind: .learningPlan, title: "Antenatal İzlem Planı", subtitle: "Trimester takibi", icon: "checklist"),
            DisciplineTool(kind: .mindMap, title: "Zihin Haritası", subtitle: "Kavram ilişkileri", icon: "point.3.connected.trianglepath.dotted"),
            DisciplineTool(kind: .examMorningSummary, title: "Sınav Sabahı", subtitle: "Kritik tarama", icon: "bolt"),
            DisciplineTool(kind: .infographic, title: "İnfografik", subtitle: "Görsel hafıza", icon: "chart.bar.doc.horizontal"),
            DisciplineTool(kind: .podcast, title: "Podcast", subtitle: "Dinlenebilir tekrar", icon: "mic")
        ],
        aiPersonaHint: "Ebelik öğrencisi: gebelik takibi (antenatal), doğum eylemi evreleri, partograf (servikal dilatasyon, fetal/maternal izlem), postpartum/lohusa bakımı ve neonatal bakım (APGAR) odaklı. Sınav hedefi KPSS/klinik pratik."
    )

    // MARK: - Veterinerlik

    static let veterinerlik = DisciplineOptionProfile(
        heroSubtitle: "Tür bazlı çalış — büyükbaş, küçükbaş, kanatlı, egzotik. Karşılaştırma, saha vakası ve zoonoz odaklı.",
        mainKinds: [
            DisciplineTool(kind: .comparison, title: "Tür Karşılaştırma", subtitle: "Büyükbaş · küçükbaş · kanatlı · egzotik", icon: "tablecells"),
            DisciplineTool(kind: .summary, title: "Yüksek Getirili Özet", subtitle: "Kısa ve net tekrar", icon: "doc.text"),
            DisciplineTool(kind: .flashcard, title: "Flashcard", subtitle: "Tekrar kartları", icon: "rectangle.on.rectangle"),
            DisciplineTool(kind: .algorithm, title: "Zoonoz / Karar Akışı", subtitle: "Tanıma ve yönetim adımları", icon: "arrow.triangle.branch"),
            DisciplineTool(kind: .question, title: "Soru", subtitle: "Uzmanlık ve saha soru pratiği", icon: "questionmark.circle")
        ],
        deepKinds: [
            DisciplineTool(kind: .clinicalScenario, title: "Saha Vakası", subtitle: "Tür özelinde pratik", icon: "cross.case"),
            DisciplineTool(kind: .mindMap, title: "Zihin Haritası", subtitle: "Kavram ilişkileri", icon: "point.3.connected.trianglepath.dotted"),
            DisciplineTool(kind: .examMorningSummary, title: "Sınav Sabahı", subtitle: "Kritik tarama", icon: "bolt"),
            DisciplineTool(kind: .learningPlan, title: "Öğrenme Planı", subtitle: "Günlere bölünmüş", icon: "checklist"),
            DisciplineTool(kind: .infographic, title: "İnfografik", subtitle: "Görsel hafıza", icon: "chart.bar.doc.horizontal"),
            DisciplineTool(kind: .podcast, title: "Podcast", subtitle: "Dinlenebilir tekrar", icon: "mic")
        ],
        aiPersonaHint: "Veteriner hekimlik öğrencisi: tür farkları (büyükbaş/küçükbaş/kanatlı/egzotik; doz, anatomi, semptom değişir), saha pratiği ve zoonoz odaklı; hasta = hayvan, insan hekimliği varsayma."
    )
}

// MARK: - Kind → home route mapping (iOS-only; AppRoute lives in this module)

extension GeneratedKind {
    /// The six "deep"/media kinds that live in the SourceLab / deep-tools group.
    var isDeepKind: Bool {
        switch self {
        case .clinicalScenario, .examMorningSummary, .learningPlan, .podcast, .infographic, .mindMap:
            return true
        case .flashcard, .question, .summary, .algorithm, .comparison, .table:
            return false
        }
    }

    /// Route to the per-kind factory screen (main, non-deep tools).
    var factoryRoute: AppRoute {
        switch self {
        case .flashcard: return .flashcardFactory
        case .question: return .questionFactory
        case .summary: return .summaryFactory
        case .algorithm: return .algorithmFactory
        case .comparison, .table: return .comparisonFactory
        default: return .summaryFactory
        }
    }

    /// Route to the deep/media tool screen.
    var deepRoute: AppRoute {
        switch self {
        case .clinicalScenario: return .clinical
        case .examMorningSummary: return .examMorning
        case .learningPlan: return .plan
        case .podcast: return .podcast
        case .infographic: return .infographic
        case .mindMap: return .mindMap
        default: return .clinical
        }
    }
}
