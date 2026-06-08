import Foundation
import Compression
import PDFKit
import Vision
import UniformTypeIdentifiers
import SourceBaseBackend
#if canImport(zlib)
import zlib
#endif
#if os(macOS)
import AppKit
#endif

public enum ExtractionError: Error, LocalizedError {
    case unsupportedType
    case invalidDocument
    case noReadableText
    case ocrFailed(String)
    case memoryLimit

    public var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Bu dosya türü mobilde işlenemiyor. PDF, PPT/PPTX veya DOC/DOCX yükleyebilirsin."
        case .invalidDocument:
            return "Dosya okunamadı veya bozuk."
        case .noReadableText:
            return "Bu dosyadan okunabilir metin çıkarılamadı. Metin içeren PDF, PPT/PPTX veya DOC/DOCX deneyebilirsin."
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
        case "doc", "application/msword":
            return try await extractLegacyOffice(from: url, label: "DOC")
        case "docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return try await extractDOCX(from: url)
        case "ppt", "application/vnd.ms-powerpoint":
            return try await extractLegacyOffice(from: url, label: "PPT")
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
        guard !sanitized.isEmpty else {
            throw ExtractionError.noReadableText
        }

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
        guard !sanitized.isEmpty else {
            throw ExtractionError.noReadableText
        }

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

        let paths = archive.fileNames()
            .filter { path in
                path == "word/document.xml" ||
                    path.hasPrefix("word/header") ||
                    path.hasPrefix("word/footer") ||
                    path.hasPrefix("word/footnotes") ||
                    path.hasPrefix("word/endnotes")
            }
            .sorted(by: officePathSort)

        guard !paths.isEmpty else {
            throw ExtractionError.invalidDocument
        }

        return paths
            .compactMap { archive.extractFile(named: $0) }
            .map(extractTextFromXML)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func extractPPTX(from url: URL) async throws -> ExtractionResult {
        let data = try Data(contentsOf: url)
        let (text, slideCount) = try extractTextFromPPTX(data: data)
        let sanitized = sanitizeText(text)
        guard !sanitized.isEmpty else {
            throw ExtractionError.noReadableText
        }

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
        let slidePaths = archive.fileNames()
            .filter { $0.hasPrefix("ppt/slides/slide") && $0.hasSuffix(".xml") }
            .sorted(by: officePathSort)

        guard !slidePaths.isEmpty else {
            throw ExtractionError.invalidDocument
        }

        for (index, slidePath) in slidePaths.enumerated() {
            guard let slideXML = archive.extractFile(named: slidePath) else { continue }
            let slideText = extractTextFromXML(slideXML)
            if !slideText.isEmpty {
                fullText += "\n--- Slayt \(index + 1) ---\n" + slideText
            }
        }

        let notesText = archive.fileNames()
            .filter { $0.hasPrefix("ppt/notesSlides/notesSlide") && $0.hasSuffix(".xml") }
            .sorted(by: officePathSort)
            .compactMap { archive.extractFile(named: $0) }
            .map(extractTextFromXML)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        if !notesText.isEmpty {
            fullText += "\n--- Sunum notları ---\n" + notesText
        }

        return (fullText, slidePaths.count)
    }

    private func extractTextFromXML(_ xml: String) -> String {
        let parser = OfficeXMLTextParser()
        if let parsed = parser.parse(xml), !parsed.isEmpty {
            return parsed
        }

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

    private func extractLegacyOffice(from url: URL, label: String) async throws -> ExtractionResult {
        let data = try Data(contentsOf: url)
        let text = extractReadableStrings(from: data)
        let sanitized = sanitizeText(text)
        guard !sanitized.isEmpty else {
            throw ExtractionError.noReadableText
        }

        return ExtractionResult(
            text: "--- \(label) mobil metin çıkarımı ---\n\(sanitized)",
            pageCount: 1,
            metadata: ExtractionMetadata(
                charCount: sanitized.count,
                wordCount: sanitized.split(separator: " ").count,
                extractedAt: Date()
            )
        )
    }

    private func extractReadableStrings(from data: Data) -> String {
        let bytes = [UInt8](data)
        var candidates: [String] = []
        candidates.append(contentsOf: extractUTF16LEStrings(bytes))
        candidates.append(contentsOf: extractASCIIStrings(bytes))

        var seen = Set<String>()
        return candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isUsefulOfficeText($0) && seen.insert($0).inserted }
            .prefix(4_000)
            .joined(separator: "\n")
    }

    private func extractUTF16LEStrings(_ bytes: [UInt8]) -> [String] {
        var results: [String] = []
        var scalars: [UInt16] = []

        func flush() {
            guard scalars.count >= 4 else {
                scalars.removeAll()
                return
            }
            let data = scalars.reduce(into: Data()) { partial, scalar in
                partial.append(UInt8(scalar & 0x00FF))
                partial.append(UInt8((scalar >> 8) & 0x00FF))
            }
            if let string = String(data: data, encoding: .utf16LittleEndian) {
                results.append(string)
            }
            scalars.removeAll()
        }

        var index = 0
        while index + 1 < bytes.count {
            let scalar = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
            if isPrintableOfficeScalar(scalar) {
                scalars.append(scalar)
            } else {
                flush()
            }
            index += 2
        }
        flush()
        return results
    }

    private func extractASCIIStrings(_ bytes: [UInt8]) -> [String] {
        var results: [String] = []
        var run: [UInt8] = []

        func flush() {
            guard run.count >= 8 else {
                run.removeAll()
                return
            }
            if let string = String(data: Data(run), encoding: .utf8) {
                results.append(string)
            }
            run.removeAll()
        }

        for byte in bytes {
            if byte == 9 || byte == 10 || byte == 13 || (byte >= 32 && byte <= 126) {
                run.append(byte)
            } else {
                flush()
            }
        }
        flush()
        return results
    }

    private func isPrintableOfficeScalar(_ scalar: UInt16) -> Bool {
        scalar == 9 || scalar == 10 || scalar == 13 || (scalar >= 32 && scalar < 0xD800)
    }

    private func isUsefulOfficeText(_ text: String) -> Bool {
        let letters = text.filter(\.isLetter).count
        guard letters >= 3 else { return false }
        let visible = text.filter { !$0.isWhitespace }.count
        guard visible > 0 else { return false }
        return Double(letters) / Double(max(visible, 1)) > 0.28
    }

    private func officePathSort(_ lhs: String, _ rhs: String) -> Bool {
        let leftNumber = firstNumber(in: lhs) ?? Int.max
        let rightNumber = firstNumber(in: rhs) ?? Int.max
        if leftNumber != rightNumber { return leftNumber < rightNumber }
        return lhs < rhs
    }

    private func firstNumber(in string: String) -> Int? {
        var digits = ""
        for character in string {
            if character.isNumber {
                digits.append(character)
            } else if !digits.isEmpty {
                break
            }
        }
        return digits.isEmpty ? nil : Int(digits)
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

private final class OfficeXMLTextParser: NSObject, XMLParserDelegate {
    private var text = ""
    private var activeTextElement = false
    private let textElementNames: Set<String> = ["t"]
    private let paragraphElementNames: Set<String> = ["p"]
    private let breakElementNames: Set<String> = ["br", "tab"]

    func parse(_ xml: String) -> String? {
        guard let data = xml.data(using: .utf8) else { return nil }
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse() ? text.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let localName = Self.localName(qName ?? elementName)
        if textElementNames.contains(localName) {
            activeTextElement = true
        } else if breakElementNames.contains(localName), activeTextElement {
            text += localName == "tab" ? "\t" : "\n"
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if activeTextElement {
            text += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let localName = Self.localName(qName ?? elementName)
        if textElementNames.contains(localName) {
            activeTextElement = false
            text += " "
        } else if paragraphElementNames.contains(localName), !text.hasSuffix("\n") {
            text += "\n"
        }
    }

    private static func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
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

    func fileNames() -> [String] {
        let central = centralDirectoryEntries().map(\.path)
        if !central.isEmpty { return central }
        return localHeaderFileNames()
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

        #if canImport(zlib)
        if let decoded = try? inflateWithZlib(payload, expectedSize: expectedSize),
           !decoded.isEmpty || expectedSize == 0 {
            return decoded
        }
        #endif

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

    #if canImport(zlib)
    private func inflateWithZlib(_ payload: Data, expectedSize: Int) throws -> Data {
        var stream = z_stream()
        let initStatus = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else {
            throw ExtractionError.invalidDocument
        }
        defer { inflateEnd(&stream) }

        var output = Data(count: max(expectedSize, payload.count * 4, 1024))
        let outputCapacity = output.count
        let status = output.withUnsafeMutableBytes { outputBuffer in
            payload.withUnsafeBytes { inputBuffer in
                guard let inputBase = inputBuffer.bindMemory(to: Bytef.self).baseAddress,
                      let outputBase = outputBuffer.bindMemory(to: Bytef.self).baseAddress else {
                    return Int32(Z_BUF_ERROR)
                }
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputBase)
                stream.avail_in = uInt(payload.count)
                stream.next_out = outputBase
                stream.avail_out = uInt(outputCapacity)
                return inflate(&stream, Z_FINISH)
            }
        }

        guard status == Z_STREAM_END || status == Z_OK else {
            throw ExtractionError.invalidDocument
        }
        let decodedCount = output.count - Int(stream.avail_out)
        guard decodedCount >= 0, decodedCount <= output.count else {
            throw ExtractionError.invalidDocument
        }
        output.removeSubrange(decodedCount..<output.count)
        return output
    }
    #endif

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

    private func localHeaderFileNames() -> [String] {
        var names: [String] = []
        var offset = 0
        while offset + 30 <= data.count {
            guard littleEndianUInt32(at: offset) == 0x04034B50 else {
                offset += 1
                continue
            }
            let compressedSize = Int(littleEndianUInt32(at: offset + 18))
            let fileNameLength = Int(littleEndianUInt16(at: offset + 26))
            let extraLength = Int(littleEndianUInt16(at: offset + 28))
            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + fileNameLength
            guard fileNameEnd <= data.count else { break }
            if let fileName = String(data: data[fileNameStart..<fileNameEnd], encoding: .utf8) {
                names.append(fileName)
            }
            let dataStart = fileNameEnd + extraLength
            let dataEnd = dataStart + compressedSize
            guard dataEnd > offset, dataEnd <= data.count else { break }
            offset = dataEnd
        }
        return names
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
