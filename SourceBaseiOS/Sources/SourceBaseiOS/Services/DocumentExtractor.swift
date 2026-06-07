import Foundation
import Compression
import PDFKit
import Vision
import UniformTypeIdentifiers
import SourceBaseBackend
#if os(macOS)
import AppKit
#endif

public enum ExtractionError: Error, LocalizedError {
    case unsupportedType
    case invalidDocument
    case ocrFailed(String)
    case memoryLimit

    public var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Bu dosya türü desteklenmiyor."
        case .invalidDocument:
            return "Dosya okunamadı veya bozuk."
        case .ocrFailed(let reason):
            return "Metin çıkarılamadı: \(reason)"
        case .memoryLimit:
            return "Dosya çok büyük. Daha küçük bir dosya deneyin."
        }
    }
}

public struct ExtractionResult: Sendable {
    public let text: String
    public let pageCount: Int
    public let metadata: ExtractionMetadata

    public init(text: String, pageCount: Int, metadata: ExtractionMetadata) {
        self.text = text
        self.pageCount = pageCount
        self.metadata = metadata
    }
}

public actor DocumentExtractor {
    public static let shared = DocumentExtractor()

    private init() {}

    public func extract(from url: URL, fileType: String) async throws -> ExtractionResult {
        let normalizedType = fileType.lowercased()

        switch normalizedType {
        case "pdf", "application/pdf":
            return try await extractPDF(from: url)
        case "docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return try await extractDOCX(from: url)
        case "pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation":
            return try await extractPPTX(from: url)
        default:
            throw ExtractionError.unsupportedType
        }
    }

    private func extractPDF(from url: URL) async throws -> ExtractionResult {
        guard let pdf = PDFDocument(url: url) else {
            throw ExtractionError.invalidDocument
        }

        var fullText = ""
        let pageCount = pdf.pageCount
        var ocrPageCount = 0

        for i in 0..<pageCount {
            guard let page = pdf.page(at: i) else { continue }

            if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fullText += "\n--- Sayfa \(i + 1) ---\n" + text
            } else {
                let ocrText = try await performOCR(on: page)
                if !ocrText.isEmpty {
                    fullText += "\n--- Sayfa \(i + 1) (OCR) ---\n" + ocrText
                    ocrPageCount += 1
                }
            }
        }

        let sanitized = sanitizeText(fullText)

        return ExtractionResult(
            text: sanitized,
            pageCount: pageCount,
            metadata: ExtractionMetadata(
                charCount: sanitized.count,
                wordCount: sanitized.split(separator: " ").count,
                extractedAt: Date()
            )
        )
    }

    private func performOCR(on page: PDFPage) async throws -> String {
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let width = Int(pageRect.width * scale)
        let height = Int(pageRect.height * scale)

        guard width > 0, height > 0, width * height < 16_000_000 else {
            throw ExtractionError.memoryLimit
        }

        let thumbnail = page.thumbnail(of: CGSize(width: width, height: height), for: .mediaBox)
        #if os(macOS)
        guard let image = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        #else
        guard let image = thumbnail.cgImage else {
            return ""
        }
        #endif

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["tr", "en"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results else { return "" }

        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private func extractDOCX(from url: URL) async throws -> ExtractionResult {
        let data = try Data(contentsOf: url)
        let text = try extractTextFromDOCX(data: data)
        let sanitized = sanitizeText(text)

        return ExtractionResult(
            text: sanitized,
            pageCount: 1,
            metadata: ExtractionMetadata(
                charCount: sanitized.count,
                wordCount: sanitized.split(separator: " ").count,
                extractedAt: Date()
            )
        )
    }

    private func extractTextFromDOCX(data: Data) throws -> String {
        guard let archive = ZIPArchive(data: data) else {
            throw ExtractionError.invalidDocument
        }

        guard let documentXML = archive.extractFile(named: "word/document.xml") else {
            throw ExtractionError.invalidDocument
        }

        return extractTextFromXML(documentXML)
    }

    private func extractPPTX(from url: URL) async throws -> ExtractionResult {
        let data = try Data(contentsOf: url)
        let (text, slideCount) = try extractTextFromPPTX(data: data)
        let sanitized = sanitizeText(text)

        return ExtractionResult(
            text: sanitized,
            pageCount: slideCount,
            metadata: ExtractionMetadata(
                charCount: sanitized.count,
                wordCount: sanitized.split(separator: " ").count,
                extractedAt: Date()
            )
        )
    }

    private func extractTextFromPPTX(data: Data) throws -> (text: String, slideCount: Int) {
        guard let archive = ZIPArchive(data: data) else {
            throw ExtractionError.invalidDocument
        }

        var fullText = ""
        var slideCount = 0

        for i in 1...1000 {
            let slidePath = "ppt/slides/slide\(i).xml"
            guard let slideXML = archive.extractFile(named: slidePath) else { break }

            let slideText = extractTextFromXML(slideXML)
            if !slideText.isEmpty {
                fullText += "\n--- Slayt \(i) ---\n" + slideText
                slideCount += 1
            }
        }

        return (fullText, slideCount)
    }

    private func extractTextFromXML(_ xml: String) -> String {
        var text = ""
        var inText = false

        let scanner = Scanner(string: xml)
        scanner.charactersToBeSkipped = nil

        while !scanner.isAtEnd {
            if let tag = scanner.scanUpToString("<") {
                if inText {
                    text += tag
                }
            }

            if scanner.scanString("<") != nil {
                if let tagName = scanner.scanUpToString(">") {
                    if tagName.hasPrefix("w:t") || tagName.hasPrefix("a:t") {
                        inText = true
                    } else if tagName.hasPrefix("/") {
                        inText = false
                    }
                }
                _ = scanner.scanString(">")
            }
        }

        return text
    }

    private func sanitizeText(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")

        let lines = result.components(separatedBy: "\n")
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        result = cleaned.joined(separator: "\n")

        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private class ZIPArchive {
    private struct CentralDirectoryEntry {
        let path: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private let data: Data

    init?(data: Data) {
        guard data.count > 4 else { return nil }
        self.data = data
    }

    func extractFile(named path: String) -> String? {
        guard let fileData = try? extractRawFile(named: path) else { return nil }
        return String(data: fileData, encoding: .utf8)
    }

    private func extractRawFile(named path: String) throws -> Data {
        if let entry = centralDirectoryEntries().first(where: { $0.path == path }) {
            return try extract(entry)
        }

        if let data = try extractFromLocalHeaders(named: path) {
            return data
        }

        throw ExtractionError.invalidDocument
    }

    private func centralDirectoryEntries() -> [CentralDirectoryEntry] {
        guard let directoryStart = endOfCentralDirectoryOffset().map({ littleEndianUInt32(at: $0 + 16) }) else {
            return []
        }

        var entries: [CentralDirectoryEntry] = []
        var offset = Int(directoryStart)
        while offset + 46 <= data.count, littleEndianUInt32(at: offset) == 0x02014B50 {
            let compressionMethod = littleEndianUInt16(at: offset + 10)
            let compressedSize = Int(littleEndianUInt32(at: offset + 20))
            let uncompressedSize = Int(littleEndianUInt32(at: offset + 24))
            let fileNameLength = Int(littleEndianUInt16(at: offset + 28))
            let extraLength = Int(littleEndianUInt16(at: offset + 30))
            let commentLength = Int(littleEndianUInt16(at: offset + 32))
            let localHeaderOffset = Int(littleEndianUInt32(at: offset + 42))
            let fileNameStart = offset + 46
            let fileNameEnd = fileNameStart + fileNameLength
            guard fileNameEnd <= data.count,
                  let path = String(data: data[fileNameStart..<fileNameEnd], encoding: .utf8) else {
                break
            }
            entries.append(CentralDirectoryEntry(
                path: path,
                compressionMethod: compressionMethod,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            ))
            offset = fileNameEnd + extraLength + commentLength
        }
        return entries
    }

    private func extract(_ entry: CentralDirectoryEntry) throws -> Data {
        let offset = entry.localHeaderOffset
        guard offset + 30 <= data.count, littleEndianUInt32(at: offset) == 0x04034B50 else {
            throw ExtractionError.invalidDocument
        }
        let fileNameLength = Int(littleEndianUInt16(at: offset + 26))
        let extraLength = Int(littleEndianUInt16(at: offset + 28))
        let dataStart = offset + 30 + fileNameLength + extraLength
        let dataEnd = dataStart + entry.compressedSize
        guard dataStart >= 0, dataEnd <= data.count else {
            throw ExtractionError.invalidDocument
        }
        let compressed = Data(data[dataStart..<dataEnd])
        return try decodeZIPPayload(
            compressed,
            method: entry.compressionMethod,
            uncompressedSize: entry.uncompressedSize
        )
    }

    private func extractFromLocalHeaders(named path: String) throws -> Data? {
        var offset = 0
        while offset + 30 <= data.count {
            guard littleEndianUInt32(at: offset) == 0x04034B50 else {
                offset += 1
                continue
            }

            let compressionMethod = littleEndianUInt16(at: offset + 8)
            let compressedSize = Int(littleEndianUInt32(at: offset + 18))
            let uncompressedSize = Int(littleEndianUInt32(at: offset + 22))
            let fileNameLength = Int(littleEndianUInt16(at: offset + 26))
            let extraLength = Int(littleEndianUInt16(at: offset + 28))
            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + fileNameLength
            guard fileNameEnd <= data.count,
                  let fileName = String(data: data[fileNameStart..<fileNameEnd], encoding: .utf8) else {
                throw ExtractionError.invalidDocument
            }

            let dataStart = fileNameEnd + extraLength
            let dataEnd = dataStart + compressedSize
            guard dataStart >= 0, dataEnd <= data.count else {
                throw ExtractionError.invalidDocument
            }
            if fileName == path {
                let compressed = Data(data[dataStart..<dataEnd])
                return try decodeZIPPayload(
                    compressed,
                    method: compressionMethod,
                    uncompressedSize: uncompressedSize
                )
            }
            offset = dataEnd
        }
        return nil
    }

    private func decodeZIPPayload(_ payload: Data, method: UInt16, uncompressedSize: Int) throws -> Data {
        switch method {
        case 0:
            return payload
        case 8:
            return try inflateRawDeflate(payload, expectedSize: uncompressedSize)
        default:
            throw ExtractionError.unsupportedType
        }
    }

    private func inflateRawDeflate(_ payload: Data, expectedSize: Int) throws -> Data {
        guard expectedSize >= 0 else { throw ExtractionError.invalidDocument }
        if payload.isEmpty { return Data() }

        var output = Data(count: max(expectedSize, payload.count * 4, 1024))
        let decodedCount = output.withUnsafeMutableBytes { outputBuffer in
            payload.withUnsafeBytes { inputBuffer in
                compression_decode_buffer(
                    outputBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    outputBuffer.count,
                    inputBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    inputBuffer.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decodedCount > 0 else {
            throw ExtractionError.invalidDocument
        }
        output.removeSubrange(decodedCount..<output.count)
        return output
    }

    private func endOfCentralDirectoryOffset() -> Int? {
        guard data.count >= 22 else { return nil }
        let minimumOffset = max(0, data.count - 65_557)
        var offset = data.count - 22
        while offset >= minimumOffset {
            if littleEndianUInt32(at: offset) == 0x06054B50 {
                return offset
            }
            offset -= 1
        }
        return nil
    }

    private func littleEndianUInt16(at offset: Int) -> UInt16 {
        guard offset + 1 < data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func littleEndianUInt32(at offset: Int) -> UInt32 {
        guard offset + 3 < data.count else { return 0 }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
