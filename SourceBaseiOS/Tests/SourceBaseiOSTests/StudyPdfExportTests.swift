import Foundation
import Testing
import SourceBaseBackend
import Supabase
@testable import SourceBaseiOS

#if canImport(PDFKit)
import PDFKit
#endif

@MainActor
@Test func exportsVisualPdfWithoutCoverAndWithWatermark() async throws {
    let summary = GeneratedOutput(
        id: "o1", sourceFileId: "f1", kind: .summary, rawType: "summary",
        title: "Kardiyoloji Özeti", detail: "",
        content: .object([
            "summary": .string("Bu konunun kısa genel bakışı."),
            "bulletPoints": .array([.string("Önemli madde bir"), .string("Önemli madde iki")]),
            "mainTopics": .array([.string("Konu A"), .string("Konu B")])
        ]),
        contentText: "Yedek metin", updatedLabel: "şimdi", status: "ready", itemCount: 2, jobId: nil
    )
    let comparison = GeneratedOutput(
        id: "o2", sourceFileId: "f1", kind: .comparison, rawType: "comparison",
        title: "A vs B", detail: "",
        content: .object([
            "title": .string("A vs B"),
            "headers": .array([.string("Özellik"), .string("A"), .string("B")]),
            "rows": .array([
                .object(["label": .string("Klinik bulgu"), "values": .array([.string("x"), .string("y")])]),
                .object(["label": .string("Tedavi"), "values": .array([.string("p"), .string("q")])])
            ]),
            "distinguishing_tips": .array([.string("Ayırt edici ipucu")])
        ]),
        contentText: nil, updatedLabel: "şimdi", status: "ready", itemCount: 1, jobId: nil
    )
    let longCards = GeneratedOutput(
        id: "o3", sourceFileId: "f1", kind: .flashcard, rawType: "flashcard",
        title: "Uzun Flashcard Seti", detail: "",
        content: .object([
            "cards": .array((1...36).map { index in
                .object([
                    "front": .string("Kart \(index): Kardiyoloji kavramı"),
                    "back": .string("Yanıt \(index): Klinik karar, sınav ipucu ve ayırıcı tanı notu."),
                    "explanation": .string("Bu kart uzun PDF akışında içerik kaybı olmadan sayfalara bölünmelidir.")
                ])
            })
        ]),
        contentText: nil, updatedLabel: "şimdi", status: "ready", itemCount: 36, jobId: nil
    )

    for output in [summary, comparison, longCards] {
        let url = try await SBStudyExportService.exportPDF(for: output)
        let data = try Data(contentsOf: url)
        #expect(data.count > 1000)
        #expect(data.prefix(4) == Data("%PDF".utf8))
        #if canImport(PDFKit)
        let pdf = PDFDocument(url: url)
        #expect((pdf?.pageCount ?? 0) >= (output.id == "o3" ? 2 : 1))
        if let pdf {
            for pageIndex in 0..<pdf.pageCount {
                #expect(pdf.page(at: pageIndex)?.string?.contains("SourceBase") == true)
            }
            let firstPageText = pdf.page(at: 0)?.string ?? ""
            #expect(firstPageText.contains("Premium Plus") || firstPageText.contains("PREMIUM PLUS"))
            if output.id == "o3" {
                #expect(pdf.page(at: 0)?.string?.contains("Kart 1") == true)
            }
        }
        #endif
    }
}
