import SwiftUI
import SourceBaseBackend

struct RichResultContentView: View {
    let kind: GeneratedKind
    let title: String
    let sourceTitle: String
    let contentText: String

    private var tint: Color {
        switch kind {
        case .flashcard: return SBColors.blue
        case .question: return SBColors.cyan
        case .summary, .examMorningSummary: return SBColors.purple
        case .algorithm, .clinicalScenario: return SBColors.orange
        case .comparison, .table: return SBColors.blue
        case .learningPlan: return SBColors.green
        case .podcast: return SBColors.red
        case .infographic: return SBColors.cyan
        case .mindMap: return SBColors.purple
        }
    }

    private var blocks: [ResultContentBlock] {
        ResultContentParser.blocks(from: contentText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            ResultBlockHeader(
                icon: icon,
                title: title,
                subtitle: sourceTitle,
                tint: tint
            )

            if blocks.isEmpty {
                rawTextCard(contentText)
            } else {
                ForEach(blocks) { block in
                    ResultContentBlockView(block: block, tint: tint)
                }
            }
        }
    }

    private var icon: String {
        switch kind {
        case .flashcard: return "rectangle.on.rectangle"
        case .question: return "questionmark.circle"
        case .summary: return "doc.text"
        case .examMorningSummary: return "alarm"
        case .algorithm: return "arrow.triangle.branch"
        case .comparison, .table: return "tablecells"
        case .clinicalScenario: return "cross.case"
        case .learningPlan: return "calendar.badge.clock"
        case .podcast: return "waveform"
        case .infographic: return "chart.bar.doc.horizontal"
        case .mindMap: return "point.3.connected.trianglepath.dotted"
        }
    }

    private func rawTextCard(_ text: String) -> some View {
        SBCard(radius: 16) {
            Text(text)
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.navy)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ResultContentBlock: Identifiable {
    let id = UUID()
    let title: String?
    let lines: [ResultContentLine]
}

private enum ResultContentLine {
    case paragraph(String)
    case bullet(String)
    case keyValue(String, String)
}

private enum ResultContentParser {
    static func blocks(from text: String) -> [ResultContentBlock] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return [] }

        var blocks: [ResultContentBlock] = []
        var currentTitle: String?
        var currentLines: [ResultContentLine] = []

        func flush() {
            guard currentTitle != nil || !currentLines.isEmpty else { return }
            blocks.append(ResultContentBlock(title: currentTitle, lines: currentLines))
            currentTitle = nil
            currentLines = []
        }

        for rawLine in normalized.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
                continue
            }

            if let heading = headingText(from: line) {
                flush()
                currentTitle = heading
                continue
            }

            currentLines.append(contentLine(from: line))
        }
        flush()

        if blocks.count == 1, blocks[0].title == nil, blocks[0].lines.count == 1 {
            return blocks
        }
        return blocks
    }

    private static func headingText(from line: String) -> String? {
        if line.hasPrefix("#") {
            return line.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).nilIfEmpty
        }
        if !line.hasPrefix("-"), !line.hasPrefix("•"), !line.contains(":"),
           line.count <= 64, line == line.uppercased() || line.hasSuffix(":"), line.count > 3 {
            return line.trimmingCharacters(in: CharacterSet(charactersIn: ":")).nilIfEmpty
        }
        return nil
    }

    private static func contentLine(from line: String) -> ResultContentLine {
        let strippedBullet = line
            .replacingOccurrences(of: #"^\s*[-•]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\d+[\.)]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        if strippedBullet != line {
            return .bullet(strippedBullet)
        }

        if let colon = line.firstIndex(of: ":") {
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, !value.isEmpty, key.count <= 36 {
                return .keyValue(key, value)
            }
        }

        return .paragraph(line)
    }
}

private struct ResultContentBlockView: View {
    let block: ResultContentBlock
    let tint: Color

    var body: some View {
        SBCard(radius: 16, borderColor: tint.opacity(0.16)) {
            VStack(alignment: .leading, spacing: SBSpacing.sm) {
                if let title = block.title {
                    HStack(spacing: SBSpacing.sm) {
                        Circle()
                            .fill(tint)
                            .frame(width: 7, height: 7)
                        Text(title)
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ForEach(Array(block.lines.enumerated()), id: \.offset) { _, line in
                    lineView(line)
                }
            }
        }
    }

    @ViewBuilder
    private func lineView(_ line: ResultContentLine) -> some View {
        switch line {
        case .paragraph(let text):
            Text(text)
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.navy)
                .fixedSize(horizontal: false, vertical: true)

        case .bullet(let text):
            HStack(alignment: .top, spacing: SBSpacing.sm) {
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                    .padding(.top, 7)
                Text(text)
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .keyValue(let key, let value):
            VStack(alignment: .leading, spacing: 3) {
                Text(key)
                    .font(SBTypography.caption)
                    .foregroundStyle(tint)
                Text(value)
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.navy)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(SBSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct ResultBlockHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: SBSpacing.md) {
            Image(systemName: icon)
                .sbScaledFont(size: 20, weight: .semibold)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SBTypography.titleMedium)
                    .foregroundStyle(SBColors.navy)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.muted)
                    .lineLimit(2)
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
