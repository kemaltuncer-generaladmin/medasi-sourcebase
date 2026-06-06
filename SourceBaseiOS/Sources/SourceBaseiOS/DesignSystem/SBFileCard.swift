import SwiftUI
import SourceBaseBackend

public enum SBFileKind: String, Equatable {
    case pdf, pptx, docx, ppt, doc, zip

    var label: String {
        switch self {
        case .pdf: return "PDF"
        case .pptx: return "PPTX"
        case .docx: return "DOCX"
        case .ppt: return "PPT"
        case .doc: return "DOC"
        case .zip: return "ZIP"
        }
    }

    var color: Color {
        switch self {
        case .pdf: return Color(red: 1.0, green: 0.19, blue: 0.19)
        case .pptx: return SBColors.orange
        case .docx: return SBColors.blue
        case .ppt: return Color(red: 0.82, green: 0.29, blue: 0.12)
        case .doc: return Color(red: 0.08, green: 0.42, blue: 0.95)
        case .zip: return SBColors.purple
        }
    }

    public static func from(_ kind: DriveFileKind) -> SBFileKind {
        switch kind {
        case .pdf: return .pdf
        case .pptx: return .pptx
        case .docx: return .docx
        case .ppt: return .ppt
        case .doc: return .doc
        case .zip: return .zip
        }
    }
}

public struct SBFileKindBadge: View {
    let kind: SBFileKind
    let compact: Bool

    public init(kind: SBFileKind, compact: Bool = false) {
        self.kind = kind
        self.compact = compact
    }

    public var body: some View {
        let size: CGFloat = compact ? 36 : 44

        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: compact ? 6 : 8)
                .fill(kind.color.opacity(0.12))
                .frame(width: size, height: size)

            Text(kind.label)
                .sbScaledFont(size: compact ? 9 : 11, weight: .bold)
                .foregroundStyle(kind.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Fold corner
            Triangle()
                .fill(kind.color.opacity(0.3))
                .frame(width: size * 0.25, height: size * 0.25)
        }
        .accessibilityLabel(kind.label)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

public struct SBFileCard: View, @preconcurrency Equatable {
    let title: String
    let kind: SBFileKind
    let status: SBStatus
    let sizeLabel: String
    let courseTitle: String
    let updatedLabel: String
    let onTap: () -> Void

    public init(
        title: String,
        kind: SBFileKind,
        status: SBStatus,
        sizeLabel: String,
        courseTitle: String,
        updatedLabel: String,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.kind = kind
        self.status = status
        self.sizeLabel = sizeLabel
        self.courseTitle = courseTitle
        self.updatedLabel = updatedLabel
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            SBCard(radius: 16) {
                VStack(alignment: .leading, spacing: SBSpacing.md) {
                    // Top row: badge + title + status
                    HStack(alignment: .top, spacing: SBSpacing.md) {
                        SBFileKindBadge(kind: kind)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: SBSpacing.xs) {
                            Text(title)
                                .font(SBTypography.titleSmall)
                                .foregroundStyle(SBColors.navy)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)

                            FlowLayout(spacing: SBSpacing.sm) {
                                SBStatusBadge(status: status, compact: true)

                                Text(kind.label)
                                    .font(SBTypography.caption)
                                    .foregroundStyle(kind.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(kind.color.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }

                        Spacer()
                    }

                    // Meta row
                    FlowLayout(spacing: SBSpacing.sm) {
                        metaPill(icon: "folder", text: courseTitle)
                        metaPill(icon: "doc", text: sizeLabel)
                    }

                    // Footer
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text("Güncellendi: \(updatedLabel)")
                                .font(SBTypography.caption)
                                .foregroundStyle(SBColors.softText)

                            Spacer()

                            openLabel
                                .accessibilityHidden(true)
                        }

                        VStack(alignment: .leading, spacing: SBSpacing.xs) {
                            Text("Güncellendi: \(updatedLabel)")
                                .font(SBTypography.caption)
                                .foregroundStyle(SBColors.softText)
                            openLabel
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(kind.label)")
        .accessibilityValue("\(status.accessibilityText). \(courseTitle). \(sizeLabel). Güncellendi: \(updatedLabel)")
        .accessibilityHint("Dosyayı açar")
        .accessibilityAddTraits(.isButton)
    }

    public static func == (lhs: SBFileCard, rhs: SBFileCard) -> Bool {
        guard lhs.title == rhs.title else { return false }
        guard lhs.kind == rhs.kind else { return false }
        guard lhs.status == rhs.status else { return false }
        guard lhs.sizeLabel == rhs.sizeLabel else { return false }
        guard lhs.courseTitle == rhs.courseTitle else { return false }
        guard lhs.updatedLabel == rhs.updatedLabel else { return false }
        return true
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .sbScaledFont(size: 11)
                .foregroundStyle(SBColors.muted)
                .accessibilityHidden(true)
            Text(text)
                .font(SBTypography.caption)
                .foregroundStyle(SBColors.navy)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(SBColors.field.opacity(0.82))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(SBColors.softLine, lineWidth: 1)
        )
    }

    private var openLabel: some View {
        HStack(spacing: 4) {
            Text("Aç")
                .font(SBTypography.labelSmall)
                .foregroundStyle(SBColors.blue)

            Image(systemName: "chevron.right")
                .sbScaledFont(size: 12, weight: .semibold)
                .foregroundStyle(SBColors.blue)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SBFileCard(
            title: "Anatomi Ders Notları - Kas İskelet Sistemi",
            kind: .pdf,
            status: .ready,
            sizeLabel: "2.4 MB",
            courseTitle: "Anatomi",
            updatedLabel: "Bugün"
        ) {}

        SBFileCard(
            title: "Farmakoloji Sunum",
            kind: .pptx,
            status: .processing,
            sizeLabel: "8.1 MB",
            courseTitle: "Farmakoloji",
            updatedLabel: "Dün"
        ) {}

        SBFileCard(
            title: "Patoloji Özet",
            kind: .docx,
            status: .failed,
            sizeLabel: "1.2 MB",
            courseTitle: "Patoloji",
            updatedLabel: "2 gün önce"
        ) {}
    }
    .padding()
    .sbPageBackground()
}
