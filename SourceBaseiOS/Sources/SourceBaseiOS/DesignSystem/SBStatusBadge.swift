import SwiftUI
import SourceBaseBackend

public enum SBStatus: Equatable {
    case ready, processing, uploading, failed, draft

    var label: String {
        switch self {
        case .ready: return "Hazır"
        case .processing: return "İşleniyor"
        case .uploading: return "Yükleniyor"
        case .failed: return "Hatalı"
        case .draft: return "Beklemede"
        }
    }

    var color: Color {
        switch self {
        case .ready: return SBColors.green
        case .processing, .uploading: return SBColors.blue
        case .failed: return SBColors.red
        case .draft: return SBColors.warning
        }
    }

    var backgroundColor: Color {
        switch self {
        case .ready: return SBColors.greenBg
        case .processing, .uploading: return SBColors.selectedBlue
        case .failed: return SBColors.redBg
        case .draft: return SBColors.warningBg
        }
    }

    var iconName: String {
        switch self {
        case .ready: return "checkmark.circle.fill"
        case .processing: return "hourglass"
        case .uploading: return "icloud.and.arrow.up"
        case .failed: return "exclamationmark.triangle.fill"
        case .draft: return "doc.fill"
        }
    }

    var accessibilityText: String {
        "Durum: \(label)"
    }

    public static func from(_ driveStatus: DriveItemStatus) -> SBStatus {
        switch driveStatus {
        case .completed: return .ready
        case .processing: return .processing
        case .uploading: return .uploading
        case .failed: return .failed
        case .draft: return .draft
        }
    }
}

public struct SBStatusBadge: View {
    let status: SBStatus
    let compact: Bool

    public init(status: SBStatus, compact: Bool = false) {
        self.status = status
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            if status == .processing || status == .uploading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: status.color))
                    .scaleEffect(compact ? 0.7 : 0.85)
            } else {
                Image(systemName: status.iconName)
                    .sbScaledFont(size: compact ? 12 : 14, weight: .semibold)
                    .foregroundStyle(status.color)
            }

            Text(status.label)
                .sbScaledFont(size: compact ? 11 : 13, weight: .bold)
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 5 : 7)
        .background(status.backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(status.color.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        SBStatusBadge(status: .ready)
        SBStatusBadge(status: .processing)
        SBStatusBadge(status: .uploading)
        SBStatusBadge(status: .failed)
        SBStatusBadge(status: .draft)
        Divider()
        HStack(spacing: 8) {
            SBStatusBadge(status: .ready, compact: true)
            SBStatusBadge(status: .processing, compact: true)
            SBStatusBadge(status: .failed, compact: true)
        }
    }
    .padding()
    .sbPageBackground()
}
