import Foundation
import SwiftUI
import SourceBaseBackend

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private struct StudyExportProfile {
    let blockCount: Int
    let highYieldCount: Int
    let questionCount: Int
    let tableCount: Int
    let estimatedMinutes: Int

    static func make(for doc: SBStudyDocument) -> StudyExportProfile {
        var highYield = doc.summary.isEmpty ? 0 : 1
        var questions = 0
        var tables = 0
        var units = doc.summary.isEmpty ? 0 : 1

        for block in doc.blocks {
            units += 1
            switch block {
            case let .calloutList(_, _, items, style):
                if style == .mustKnow || style == .redFlag || style == .tip {
                    highYield += max(items.count, 1)
                }
                units += items.count
            case let .steps(_, _, items):
                units += items.count
            case let .decisions(_, _, nodes):
                highYield += nodes.count
                units += nodes.flatMap(\.substeps).count
            case let .table(_, _, table):
                tables += 1
                units += table.rows.count
            case let .qa(_, _, pairs):
                questions += pairs.count
                units += pairs.count
            case let .cards(_, cards):
                highYield += cards.count
                units += cards.count
            case let .quiz(_, qs):
                questions += qs.count
                units += qs.count
            case let .timeline(_, _, entries):
                units += entries.reduce(0) { $0 + $1.items.count }
            case let .mindBranches(_, _, branches):
                units += branches.reduce(0) { $0 + $1.children.count }
            case let .keyValues(_, _, pairs):
                units += pairs.count
            case let .audio(_, _, segments):
                units += segments.count
            case .paragraph, .image:
                break
            }
        }

        return StudyExportProfile(
            blockCount: doc.blocks.count,
            highYieldCount: highYield,
            questionCount: questions,
            tableCount: tables,
            estimatedMinutes: max(6, min(90, Int(ceil(Double(max(units, 1)) * 0.75))))
        )
    }

    var metricLabels: [(String, String)] {
        [
            ("Bölüm", "\(max(blockCount, 1))"),
            ("High-yield", "\(highYieldCount)"),
            ("Soru", "\(questionCount)"),
            ("Tablo", "\(tableCount)"),
            ("Süre", "\(estimatedMinutes) dk")
        ]
    }
}

#if canImport(AppKit) && !canImport(UIKit)

@MainActor
private enum AppKitStudyPDF {
    private static let page = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let margin: CGFloat = 44
    private static let width: CGFloat = 507

    static func render(doc: SBStudyDocument) -> Data {
        let data = NSMutableData()
        var mediaBox = page
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data(SBStudyExportService.exportText(doc).utf8)
        }

        drawContent(doc, in: context)
        context.closePDF()
        return data as Data
    }

    private static func drawContent(_ doc: SBStudyDocument, in context: CGContext) {
        let lines = SBStudyExportService.exportText(doc)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let profile = StudyExportProfile.make(for: doc)
        var index = 0
        var pageNumber = 1

        repeat {
            drawPage(in: context) {
                var y = drawHeader(doc, profile: profile, pageNumber: pageNumber)
                let bottomLimit = page.height - 76

                while index < lines.count {
                    let line = lines[index]
                    let isHeading = !line.hasPrefix("•") && line.count < 48
                    let font: NSFont = isHeading ? .systemFont(ofSize: 13, weight: .bold) : .systemFont(ofSize: 12)
                    let color: NSColor = isHeading ? .labelColor : .secondaryLabelColor
                    let spacing: CGFloat = isHeading ? 8 : 5
                    let height = textHeight(line, font: font, lineSpacing: 3)

                    guard y + height + spacing <= bottomLimit || y < 140 else { break }
                    y += drawText(line, x: margin, y: y, font: font, color: color, lineSpacing: 3) + spacing
                    index += 1
                }

                drawFooter(pageNumber: pageNumber)
            }
            pageNumber += 1
        } while index < lines.count
    }

    @discardableResult
    private static func drawHeader(_ doc: SBStudyDocument, profile: StudyExportProfile, pageNumber: Int) -> CGFloat {
        var y: CGFloat = 36
        let accentColor = accent(for: doc.kind)
        y += drawText(
            "SourceBase Premium Plus · \(doc.kind.titleLabel.uppercased())",
            x: margin,
            y: y,
            font: .systemFont(ofSize: 9, weight: .bold),
            color: accentColor,
            lineSpacing: 2
        ) + 8
        y += drawText(
            pageNumber == 1 ? doc.title : "\(doc.title) · devam",
            x: margin,
            y: y,
            font: .systemFont(ofSize: pageNumber == 1 ? 18 : 14, weight: .bold),
            color: accentColor,
            lineSpacing: 4
        ) + 8
        if pageNumber == 1, !doc.subtitle.isEmpty {
            y += drawText(
                doc.subtitle,
                x: margin,
                y: y,
                font: .systemFont(ofSize: 12, weight: .semibold),
                color: .secondaryLabelColor
            ) + 8
        }
        if pageNumber == 1, !doc.summary.isEmpty {
            y += drawText(
                doc.summary,
                x: margin,
                y: y,
                font: .systemFont(ofSize: 12),
                color: .labelColor,
                lineSpacing: 4
            ) + 14
        }
        if pageNumber == 1 {
            let metrics = profile.metricLabels
                .filter { $0.1 != "0" && $0.1 != "0 dk" }
                .map { "\($0.0): \($0.1)" }
                .joined(separator: "   ·   ")
            if !metrics.isEmpty {
                y += drawText(
                    metrics,
                    x: margin,
                    y: y,
                    font: .monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
                    color: .tertiaryLabelColor,
                    lineSpacing: 2
                ) + 14
            }
        }
        return y + 10
    }

    private static func drawFooter(pageNumber: Int) {
        _ = drawText(
            "SourceBase Premium Plus · Sayfa \(pageNumber)",
            x: margin,
            y: page.height - 46,
            font: .systemFont(ofSize: 10, weight: .medium),
            color: .tertiaryLabelColor
        )
        _ = drawText(
            "SOURCEBASE PREMIUM PLUS",
            x: margin,
            y: page.height - 28,
            font: .monospacedSystemFont(ofSize: 5, weight: .medium),
            color: NSColor(calibratedWhite: 0, alpha: 0.16),
            lineSpacing: 1
        )
    }

    private static func drawPage(in context: CGContext, body: () -> Void) {
        context.beginPDFPage(nil)
        context.saveGState()
        context.translateBy(x: 0, y: page.height)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        NSColor.white.setFill()
        NSBezierPath(rect: page).fill()
        drawWatermark()
        body()
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
        context.endPDFPage()
    }

    @discardableResult
    private static func drawText(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        font: NSFont,
        color: NSColor,
        lineSpacing: CGFloat = 3
    ) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ])
        let rect = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let height = ceil(rect.height) + 4
        attributed.draw(
            with: CGRect(x: x, y: y, width: width, height: height),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return height
    }

    private static func textHeight(_ text: String, font: NSFont, lineSpacing: CGFloat = 3) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: style
        ])
        let rect = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(rect.height) + 4
    }

    private static func drawWatermark() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 38, weight: .bold),
            .foregroundColor: NSColor(calibratedWhite: 0, alpha: 0.035)
        ]
        for y in stride(from: CGFloat(90), through: page.height + 120, by: 150) {
            for x in stride(from: CGFloat(-80), through: page.width + 120, by: 220) {
                NSGraphicsContext.saveGraphicsState()
                let transform = NSAffineTransform()
                transform.translateX(by: x, yBy: y)
                transform.rotate(byDegrees: -28)
                transform.concat()
                NSString(string: "SourceBase Premium Plus").draw(at: .zero, withAttributes: attributes)
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }

    private static func accent(for kind: GeneratedKind) -> NSColor {
        // Mirror SBOutputStyle.outputColor so the macOS standalone PDF matches the
        // diversified per-kind accents used in-app and in the iOS export path.
        switch kind {
        case .flashcard:
            return NSColor(calibratedRed: 0.04, green: 0.36, blue: 0.95, alpha: 1)
        case .question:
            return NSColor(calibratedRed: 0.18, green: 0.48, blue: 1.0, alpha: 1)
        case .comparison, .table:
            return NSColor(calibratedRed: 0.04, green: 0.25, blue: 0.90, alpha: 1)
        case .summary:
            return NSColor(calibratedRed: 0.48, green: 0.25, blue: 0.95, alpha: 1)
        case .examMorningSummary:
            return NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.04, alpha: 1)
        case .algorithm:
            return NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.075, alpha: 1)
        case .clinicalScenario:
            return NSColor(calibratedRed: 1.0, green: 0.23, blue: 0.23, alpha: 1)
        case .learningPlan:
            return NSColor(calibratedRed: 0.07, green: 0.68, blue: 0.33, alpha: 1)
        case .podcast:
            return NSColor(calibratedRed: 1.0, green: 0.23, blue: 0.23, alpha: 1)
        case .infographic, .mindMap:
            return NSColor(calibratedRed: 0.03, green: 0.78, blue: 0.84, alpha: 1)
        }
    }
}

#endif

/// Visual, design-matched PDF exporter. Instead of flowing plain text, it
/// renders the SAME SwiftUI card language the study screen uses (tinted callout
/// boxes, accent panels, tables, timelines, decision cards) to PDF pages via
/// `ImageRenderer`, so the export looks like a premium, branded document that
/// matches the app one-to-one. Always rendered in light mode for clean paper.
@MainActor
enum SBStudyExportService {

    static func exportPDF(for output: GeneratedOutput) async throws -> URL {
        let doc = output.studyDocument
        let safeTitle = doc.title
            .replacingOccurrences(of: "[^A-Za-z0-9ğüşöçıİĞÜŞÖÇ -]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let fileName = "\(safeTitle.isEmpty ? "SourceBase" : safeTitle)-Medasi.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        #if canImport(UIKit)
        // Best-effort: load the infographic image so it can be placed in-page.
        var image: UIImage?
        for case let .image(_, blockURL?, _) in doc.blocks {
            if let data = try? await Data(from: blockURL, timeout: 8) { image = UIImage(data: data) }
            break
        }
        let data = StudyPDF.render(doc: doc, image: image)
        try data.write(to: url, options: .atomic)
        #elseif canImport(AppKit)
        let data = AppKitStudyPDF.render(doc: doc)
        try data.write(to: url, options: .atomic)
        #else
        try exportText(doc).write(to: url, atomically: true, encoding: .utf8)
        #endif
        return url
    }

    static func exportPodcastAudio(for output: GeneratedOutput) async throws -> URL {
        guard let remoteURL = output.podcastContent.audioURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try await Data(from: remoteURL, timeout: 30)
        let ext = audioExtension(for: remoteURL)
        let safeTitle = output.podcastContent.title
            .replacingOccurrences(of: "[^A-Za-z0-9ğüşöçıİĞÜŞÖÇ -]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let fileName = "\(safeTitle.isEmpty ? "SourceBase-Podcast" : safeTitle)-Medasi.\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func exportInfographicImage(for output: GeneratedOutput) async throws -> URL {
        guard let remoteURL = output.infographicContent.imageURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try await Data(from: remoteURL, timeout: 30)
        let ext = imageExtension(for: remoteURL)
        let safeTitle = output.infographicContent.title
            .replacingOccurrences(of: "[^A-Za-z0-9ğüşöçıİĞÜŞÖÇ -]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let fileName = "\(safeTitle.isEmpty ? "SourceBase-Infografik" : safeTitle)-Medasi.\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    nonisolated static func exportText(_ doc: SBStudyDocument) -> String {
        var lines = [doc.title, "Medasi SourceBase Premium Plus", ""]
        if !doc.summary.isEmpty { lines.append(doc.summary); lines.append("") }
        for block in doc.blocks {
            switch block {
            case let .paragraph(_, t): lines.append(t)
            case let .calloutList(_, title, items, _), let .steps(_, title, items):
                lines.append(title); lines += items.map { "• \($0)" }
            case let .decisions(_, title, nodes):
                lines.append(title); lines += nodes.map { "• \($0.title)" }
            case let .table(_, title, table):
                lines.append(title); lines += table.rows.map { $0.joined(separator: " | ") }
            case let .keyValues(_, title, pairs):
                lines.append(title); lines += pairs.map { "\($0.key): \($0.value)" }
            case let .qa(_, title, pairs):
                lines.append(title); lines += pairs.flatMap { ["S: \($0.question)", "C: \($0.answer)"] }
            case let .timeline(_, title, entries):
                lines.append(title); lines += entries.map { "• \($0.title) \($0.meta)" }
            case let .mindBranches(_, title, branches):
                lines.append(title); lines += branches.map { "• \($0.label)" }
            case let .cards(_, cards): lines += cards.map { "\($0.front) — \($0.back)" }
            case let .quiz(_, qs): lines += qs.map { $0.text }
            case let .image(_, _, caption): lines.append(caption)
            case let .audio(_, url, segments):
                lines.append("Sesli anlatım: \(url?.absoluteString ?? "-")"); lines += segments.map { $0.text }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func audioExtension(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ["m4a", "mp3", "wav", "aac"].contains(ext) { return ext }
        return "m4a"
    }

    private static func imageExtension(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "webp"].contains(ext) { return ext == "jpeg" ? "jpg" : ext }
        return "png"
    }
}

// MARK: - Async data fetch (best-effort, time-bounded)

private extension Data {
    init(from url: URL, timeout: TimeInterval) async throws {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let (data, _) = try await URLSession.shared.data(for: request)
        self = data
    }
}

#if canImport(UIKit)

// MARK: - PDF rendering engine (SwiftUI → paginated A4)

@MainActor
enum StudyPDF {
    static let pageW: CGFloat = 595
    static let pageH: CGFloat = 842
    static let sideMargin: CGFloat = 34
    static let contentWidth: CGFloat = 595 - 68
    /// Vertical budget for blocks on a content page (between header and footer).
    static let contentBudget: CGFloat = 720
    static let firstPageContentBudget: CGFloat = 580
    static let blockSpacing: CGFloat = 8

    static func render(doc: SBStudyDocument, image: UIImage?) -> Data {
        let accent = SBOutputStyle.accent(for: doc.kind)
        let profile = StudyExportProfile.make(for: doc)

        // 1) Pack blocks into pages by measured height.
        var pages: [[SBStudyBlock]] = []
        var current: [SBStudyBlock] = []
        var height: CGFloat = 0
        var budget = firstPageContentBudget

        for block in splitBlocksForPagination(doc.blocks) {
            let view = PrintBlock(block: block, accent: accent, image: image)
            let h = measure(view)
            let add = h + (current.isEmpty ? 0 : blockSpacing)
            if !current.isEmpty, height + add > budget {
                pages.append(current)
                current = [block]
                height = h
                budget = contentBudget
            } else {
                current.append(block)
                height += add
            }
        }
        if !current.isEmpty { pages.append(current) }
        if pages.isEmpty { pages = [[]] }

        // 2) Render paginated study pages. The user asked for no cover page;
        // every exported page carries a subtle SourceBase watermark instead.
        let bounds = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "SourceBase",
            kCGPDFContextAuthor as String: "Medasi",
            kCGPDFContextTitle as String: doc.title
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        let total = pages.count
        return renderer.pdfData { ctx in
            for (index, blocks) in pages.enumerated() {
                draw(
                    ContentPage(
                        doc: doc,
                        profile: profile,
                        blocks: blocks,
                        accent: accent,
                        image: image,
                        pageNumber: index + 1,
                        totalPages: total
                    ),
                    into: ctx
                )
                drawSearchableTextLayer(doc: doc, pageNumber: index + 1, totalPages: total)
            }
        }
    }

    private static func splitBlocksForPagination(_ blocks: [SBStudyBlock]) -> [SBStudyBlock] {
        blocks.flatMap(splitBlock)
    }

    private static func splitBlock(_ block: SBStudyBlock) -> [SBStudyBlock] {
        switch block {
        case let .paragraph(id, text):
            return textChunks(text).enumerated().map { index, text in
                .paragraph(id: chunkId(id, index), text: text)
            }
        case let .calloutList(id, title, items, style):
            return chunked(items, size: 10).enumerated().map { index, items in
                .calloutList(id: chunkId(id, index), title: continuedTitle(title, index), items: items, style: style)
            }
        case let .steps(id, title, items):
            return chunked(items, size: 9).enumerated().map { index, items in
                .steps(id: chunkId(id, index), title: continuedTitle(title, index), items: items)
            }
        case let .decisions(id, title, nodes):
            return chunked(nodes, size: 4).enumerated().map { index, nodes in
                .decisions(id: chunkId(id, index), title: continuedTitle(title, index), nodes: nodes)
            }
        case let .table(id, title, table):
            return chunked(table.rows, size: 12).enumerated().map { index, rows in
                .table(id: chunkId(id, index), title: continuedTitle(title, index), table: SBStudyTable(headers: table.headers, rows: rows))
            }
        case let .keyValues(id, title, pairs):
            return chunked(pairs, size: 10).enumerated().map { index, pairs in
                .keyValues(id: chunkId(id, index), title: continuedTitle(title, index), pairs: pairs)
            }
        case let .qa(id, title, pairs):
            return chunked(pairs, size: 5).enumerated().map { index, pairs in
                .qa(id: chunkId(id, index), title: continuedTitle(title, index), pairs: pairs)
            }
        case let .timeline(id, title, entries):
            return chunked(entries, size: 4).enumerated().map { index, entries in
                .timeline(id: chunkId(id, index), title: continuedTitle(title, index), entries: entries)
            }
        case let .mindBranches(id, title, branches):
            return chunked(branches, size: 4).enumerated().map { index, branches in
                .mindBranches(id: chunkId(id, index), title: continuedTitle(title, index), branches: branches)
            }
        case let .cards(id, cards):
            return chunked(cards, size: 8).enumerated().map { index, cards in
                .cards(id: chunkId(id, index), cards: cards)
            }
        case let .quiz(id, questions):
            return chunked(questions, size: 5).enumerated().map { index, questions in
                .quiz(id: chunkId(id, index), questions: questions)
            }
        case .image:
            return [block]
        case let .audio(id, url, segments):
            return chunked(segments, size: 7).enumerated().map { index, segments in
                .audio(id: chunkId(id, index), url: index == 0 ? url : nil, segments: segments)
            }
        }
    }

    private static func chunkId(_ id: String, _ index: Int) -> String {
        index == 0 ? id : "\(id)-pdf-\(index)"
    }

    private static func continuedTitle(_ title: String, _ index: Int) -> String {
        index == 0 ? title : "\(title) (devam)"
    }

    private static func chunked<T>(_ values: [T], size: Int) -> [[T]] {
        guard !values.isEmpty else { return [] }
        return stride(from: 0, to: values.count, by: max(size, 1)).map { start in
            Array(values[start..<min(start + max(size, 1), values.count)])
        }
    }

    private static func textChunks(_ text: String, maxLength: Int = 1150) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed.isEmpty ? [] : [trimmed] }
        var chunks: [String] = []
        var current = ""
        for word in trimmed.split(separator: " ") {
            let next = current.isEmpty ? String(word) : "\(current) \(word)"
            if next.count > maxLength, !current.isEmpty {
                chunks.append(current)
                current = String(word)
            } else {
                current = next
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private static func draw(_ view: some View, into ctx: UIGraphicsPDFRendererContext) {
        ctx.beginPage()
        let sized = view.frame(width: pageW, height: pageH).environment(\.colorScheme, .light)
        let imageRenderer = ImageRenderer(content: sized)
        imageRenderer.scale = 3

        if let image = imageRenderer.uiImage {
            image.draw(in: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        } else {
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: pageH)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            imageRenderer.render(rasterizationScale: 3) { _, render in
                render(ctx.cgContext)
            }
            ctx.cgContext.restoreGState()
        }
    }

    private static func drawSearchableTextLayer(doc: SBStudyDocument, pageNumber: Int, totalPages: Int) {
        let text = "SourceBase Premium Plus · \(doc.title) · \(doc.kind.titleLabel) · Sayfa \(pageNumber) / \(totalPages)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 5, weight: .medium),
            .foregroundColor: UIColor.black.withAlphaComponent(0.18)
        ]
        NSString(string: text).draw(at: CGPoint(x: sideMargin, y: pageH - 18), withAttributes: attributes)
    }

    private static func measure(_ view: some View) -> CGFloat {
        let sized = view
            .frame(width: contentWidth)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, .light)
        let r = ImageRenderer(content: sized)
        r.scale = 1
        return r.uiImage?.size.height ?? 120
    }
}

// MARK: - Content page chrome

private struct ContentPage: View {
    let doc: SBStudyDocument
    let profile: StudyExportProfile
    let blocks: [SBStudyBlock]
    let accent: Color
    let image: UIImage?
    let pageNumber: Int
    let totalPages: Int

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, SBColors.field.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 0) {
                pageHeader

                if pageNumber == 1 {
                    DocumentIntro(doc: doc, profile: profile, accent: accent)
                        .padding(.horizontal, StudyPDF.sideMargin)
                        .padding(.top, 8)
                } else {
                    continuationBar
                        .padding(.horizontal, StudyPDF.sideMargin)
                        .padding(.top, 8)
                }

                VStack(alignment: .leading, spacing: StudyPDF.blockSpacing) {
                    ForEach(blocks) { block in
                        PrintBlock(block: block, accent: accent, image: image)
                    }
                }
                .padding(.horizontal, StudyPDF.sideMargin)
                .padding(.top, 10)

                Spacer(minLength: 0)

                pageFooter
            }
            PDFWatermarkLayer(accent: accent)
        }
        .frame(width: StudyPDF.pageW, height: StudyPDF.pageH, alignment: .top)
    }

    private var pageHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accent)
                        .frame(width: 18, height: 6)
                    Text("SourceBase")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SBColors.navy)
                    Text("Premium Plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.1), in: Capsule())
                }

                Spacer()

                Text(doc.kind.titleLabel.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(SBColors.muted)
                Text("\(pageNumber)/\(totalPages)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 19)
                    .background(accent, in: Capsule())
            }
            .padding(.horizontal, StudyPDF.sideMargin)
            .padding(.top, 16)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.65), SBColors.line.opacity(0.45), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.8)
                .padding(.horizontal, StudyPDF.sideMargin)
        }
    }

    private var continuationBar: some View {
        HStack(spacing: 7) {
            Image(systemName: SBOutputStyle.icon(for: doc.kind))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 21, height: 21)
                .background(accent, in: RoundedRectangle(cornerRadius: 6))
            Text(doc.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SBColors.navy)
                .lineLimit(1)
            Spacer()
            Text("devam")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(accent.opacity(0.1), in: Capsule())
        }
        .padding(8)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(SBColors.line.opacity(0.8), lineWidth: 0.8))
    }

    private var pageFooter: some View {
        HStack {
            Text("Medasi SourceBase · tablet ve çıktı için optimize edildi")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(SBColors.softText)
            Spacer()
            Text("Sayfa \(pageNumber) / \(totalPages)")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(SBColors.muted)
        }
        .padding(.horizontal, StudyPDF.sideMargin)
        .padding(.bottom, 14)
    }
}

private struct DocumentIntro: View {
    let doc: SBStudyDocument
    let profile: StudyExportProfile
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: SBOutputStyle.icon(for: doc.kind))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        LinearGradient(colors: [accent, accent.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(SBOutputStyle.templateName(doc.kind).uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(accent)
                        Text("STUDY PACK")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(SBColors.muted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(SBColors.field, in: Capsule())
                    }
                    Text(doc.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(SBOutputStyle.templatePurpose(doc.kind))
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(accent)
                .fixedSize(horizontal: false, vertical: true)

            if !doc.subtitle.isEmpty {
                Text(doc.subtitle)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(SBColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            MetricStrip(profile: profile, accent: accent)

            if !doc.summary.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(accent)
                        .frame(width: 18, height: 18)
                        .background(accent.opacity(0.1), in: Circle())
                    Text(doc.summary)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(SBColors.ink)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(9)
                .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(accent.opacity(0.12), lineWidth: 0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            ZStack(alignment: .topTrailing) {
                Color.white
                Circle()
                    .fill(accent.opacity(0.055))
                    .frame(width: 130, height: 130)
                    .offset(x: 54, y: -86)
            }
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(accent.opacity(0.18), lineWidth: 0.8))
        .shadow(color: Color.black.opacity(0.035), radius: 6, x: 0, y: 3)
    }
}

private struct MetricStrip: View {
    let profile: StudyExportProfile
    let accent: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(profile.metricLabels.enumerated()), id: \.offset) { metric in
                let shouldDim = metric.element.1 == "0"
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.element.0.uppercased())
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(SBColors.softText)
                    Text(metric.element.1)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(shouldDim ? SBColors.softText : SBColors.navy)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(shouldDim ? SBColors.field.opacity(0.55) : accent.opacity(0.075), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct PDFWatermarkLayer: View {
    let accent: Color

    var body: some View {
        ZStack {
            Text("SourceBase")
                .font(.system(size: 58, weight: .black))
                .foregroundStyle(accent.opacity(0.02))
                .rotationEffect(.degrees(-28))
                .position(x: 320, y: 430)
            Rectangle()
                .fill(accent.opacity(0.52))
                .frame(width: 3)
                .position(x: StudyPDF.sideMargin - 12, y: StudyPDF.pageH / 2)
        }
        .frame(width: StudyPDF.pageW, height: StudyPDF.pageH)
        .allowsHitTesting(false)
    }
}

// MARK: - Rich block rendering

private struct PrintBlock: View {
    let block: SBStudyBlock
    let accent: Color
    let image: UIImage?

    var body: some View {
        switch block {
        case let .paragraph(_, text):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accent.opacity(0.55))
                        .frame(width: 15, height: 4)
                    Text("Not")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(SBColors.muted)
                }
                Text(text)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(SBColors.ink)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(11)
            .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(SBColors.line.opacity(0.75), lineWidth: 0.8))

        case let .calloutList(_, title, items, style):
            let look = SBOutputStyle.callout(style, accent: accent)
            calloutBox(title: title, icon: look.icon, color: look.color) {
                ForEach(Array(items.enumerated()), id: \.offset) { item in
                    bullet(item.element, color: look.color)
                }
            }

        case let .steps(_, title, items):
            card(title: title, icon: "list.number", color: accent) {
                ForEach(Array(items.enumerated()), id: \.offset) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(item.offset + 1)")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 19, height: 19).background(accent, in: Circle())
                        Text(item.element).font(.system(size: 11.5)).foregroundStyle(SBColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case let .decisions(_, title, nodes):
            card(title: title, icon: "arrow.triangle.branch", color: accent) {
                ForEach(nodes) { node in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(node.title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(SBColors.navy)
                        if !node.detail.isEmpty {
                            Text(node.detail).font(.system(size: 10.5)).foregroundStyle(SBColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 6) {
                            if !node.yes.isEmpty { pill("Evet → \(node.yes)", color: SBColors.green) }
                            if !node.no.isEmpty { pill("Hayır → \(node.no)", color: SBColors.red) }
                        }
                        ForEach(Array(node.substeps.enumerated()), id: \.offset) { step in
                            bullet(step.element, color: accent.opacity(0.85))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(SBColors.field.opacity(0.72), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(accent.opacity(0.09), lineWidth: 0.8))
                }
            }

        case let .table(_, title, table):
            card(title: title, icon: "tablecells", color: accent) {
                tableGrid(table)
            }

        case let .keyValues(_, title, pairs):
            card(title: title, icon: "person.text.rectangle", color: accent) {
                ForEach(pairs) { pair in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.key).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(accent)
                        Text(pair.value).font(.system(size: 11.5)).foregroundStyle(SBColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }

        case let .qa(_, title, pairs):
            card(title: title, icon: "questionmark.bubble", color: accent) {
                ForEach(pairs) { pair in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pair.question).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(SBColors.navy)
                        if !pair.answer.isEmpty {
                            Text(pair.answer).font(.system(size: 11.5, weight: .medium)).foregroundStyle(SBColors.green)
                        }
                        if !pair.explanation.isEmpty {
                            Text(pair.explanation).font(.system(size: 10.5)).foregroundStyle(SBColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9).background(SBColors.field, in: RoundedRectangle(cornerRadius: 8))
                }
            }

        case let .timeline(_, title, entries):
            card(title: title, icon: "calendar", color: accent) {
                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: 9) {
                        VStack(spacing: 0) {
                            Circle().fill(accent).frame(width: 9, height: 9)
                            Rectangle().fill(accent.opacity(0.25)).frame(width: 2)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(entry.title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(SBColors.navy)
                                Spacer()
                                if !entry.meta.isEmpty {
                                    Text(entry.meta).font(.system(size: 8.5, weight: .semibold)).foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(accent, in: Capsule())
                                }
                            }
                            ForEach(Array(entry.items.enumerated()), id: \.offset) { item in
                                bullet(item.element, color: accent)
                            }
                        }
                    }
                }
            }

        case let .mindBranches(_, title, branches):
            card(title: title, icon: "point.3.connected.trianglepath.dotted", color: accent) {
                ForEach(branches) { branch in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(branch.label).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(accent)
                        ForEach(Array(branch.children.enumerated()), id: \.offset) { child in
                            bullet(child.element, color: accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 9)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.4)).frame(width: 3)
                    }
                }
            }

        case let .cards(_, cards):
            card(title: "Kartlar", icon: "rectangle.on.rectangle", color: accent) {
                ForEach(cards) { c in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .top, spacing: 7) {
                            Text("Q")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 17, height: 17)
                                .background(accent, in: Circle())
                            Text(c.front)
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(SBColors.navy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(alignment: .top, spacing: 7) {
                            Text("A")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(accent)
                                .frame(width: 17, height: 17)
                                .background(accent.opacity(0.12), in: Circle())
                            Text(c.back)
                                .font(.system(size: 11.5))
                                .foregroundStyle(SBColors.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !c.explanation.isEmpty {
                            Text(c.explanation)
                                .font(.system(size: 10))
                                .foregroundStyle(SBColors.muted)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, 24)
                        }
                        if !c.hint.isEmpty || !c.difficulty.isEmpty {
                            HStack(spacing: 5) {
                                if !c.difficulty.isEmpty { pill(c.difficulty, color: accent) }
                                if !c.hint.isEmpty { pill("İpucu: \(c.hint)", color: SBColors.orange) }
                            }
                            .padding(.leading, 24)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(accent.opacity(0.12), lineWidth: 0.8))
                }
            }

        case let .quiz(_, questions):
            card(title: "Sorular", icon: "checklist", color: accent) {
                ForEach(Array(questions.enumerated()), id: \.offset) { item in
                    let q = item.element
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(item.offset + 1). \(q.text)").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(SBColors.navy)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(Array(q.options.enumerated()), id: \.offset) { opt in
                            let correct = opt.offset == q.correctIndex
                            HStack(alignment: .top, spacing: 6) {
                                Text(letter(opt.offset))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(correct ? .white : SBColors.muted)
                                    .frame(width: 16, height: 16)
                                    .background(correct ? SBColors.green : SBColors.line, in: Circle())
                                Text(opt.element)
                                    .font(.system(size: 10.5, weight: correct ? .semibold : .regular))
                                    .foregroundStyle(correct ? SBColors.green : SBColors.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if !q.explanation.isEmpty {
                            Text(q.explanation).font(.system(size: 10)).foregroundStyle(SBColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(SBColors.field.opacity(0.72), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(SBColors.line.opacity(0.85), lineWidth: 0.8))
                }
            }

        case let .image(_, _, caption):
            VStack(alignment: .leading, spacing: 8) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(SBColors.line, lineWidth: 1))
                }
                if !caption.isEmpty {
                    Text(caption).font(.system(size: 10)).foregroundStyle(SBColors.muted)
                }
            }

        case let .audio(_, url, segments):
            card(title: "Sesli Anlatım", icon: "waveform", color: accent) {
                if let url {
                    HStack(spacing: 6) {
                        Image(systemName: "link").font(.system(size: 9.5, weight: .bold))
                        Text(url.absoluteString).font(.system(size: 9)).lineLimit(1)
                    }
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(accent.opacity(0.1), in: Capsule())
                }
                ForEach(segments) { seg in
                    VStack(alignment: .leading, spacing: 2) {
                        if !seg.title.isEmpty {
                            Text(seg.title).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(SBColors.navy)
                        }
                        Text(seg.text).font(.system(size: 10.5)).foregroundStyle(SBColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: building blocks

    private func header(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .bold)).foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(color, in: RoundedRectangle(cornerRadius: 6))
            Text(title)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(SBColors.navy)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.28))
                .frame(width: 20, height: 4)
        }
    }

    private func card<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(title, icon: icon, color: color)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SBColors.line.opacity(0.82), lineWidth: 0.8))
        .shadow(color: Color.black.opacity(0.025), radius: 4, x: 0, y: 2)
    }

    private func calloutBox<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(color, in: RoundedRectangle(cornerRadius: 6))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SBColors.navy)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(color.opacity(0.075), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.16), lineWidth: 0.8))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3).padding(.vertical, 9)
        }
    }

    private func bullet(_ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle().fill(color).frame(width: 5, height: 5).padding(.top, 5)
            Text(text).font(.system(size: 11.5)).foregroundStyle(SBColors.ink)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }

    private func tableGrid(_ table: SBStudyTable) -> some View {
        let columns = max(table.headers.count, table.rows.map(\.count).max() ?? 1)
        return Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            if !table.headers.isEmpty {
                GridRow {
                    ForEach(Array(table.headers.prefix(columns).enumerated()), id: \.offset) { h in
                        Text(h.element).font(.system(size: 9.4, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 6).padding(.vertical, 6).background(accent)
                    }
                }
            }
            ForEach(Array(table.rows.enumerated()), id: \.offset) { row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { col in
                        Text(row.element.indices.contains(col) ? row.element[col] : "")
                            .font(.system(size: 9.4, weight: col == 0 ? .semibold : .regular))
                            .foregroundStyle(col == 0 ? SBColors.navy : SBColors.ink)
                            .lineSpacing(1.4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .background(row.offset.isMultiple(of: 2) ? SBColors.field.opacity(0.72) : Color.white)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(SBColors.line, lineWidth: 0.8))
    }

    private func letter(_ index: Int) -> String {
        guard let scalar = UnicodeScalar(65 + index) else { return "\(index + 1)" }
        return String(scalar)
    }
}

#endif
