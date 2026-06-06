import Foundation
import SourceBaseBackend

/// Minimum MC cost per generation type (standard quality), mirroring the
/// backend `MIN_UNITS` pricing floor (units / 100 = MC). The real charge is
/// computed server-side and may be higher for long sources, so copy says
/// "en az". Keeps the student informed before they spend coins.
enum SBGenerationCost {
    /// Minimum MC at standard quality.
    static func minMC(for kind: GeneratedKind) -> Double {
        switch kind {
        case .summary: return 0.5
        case .examMorningSummary: return 1.0
        case .flashcard: return 0.75
        case .question: return 1.0
        case .algorithm: return 1.0
        case .comparison, .table: return 1.5
        case .mindMap: return 1.0
        case .clinicalScenario: return 2.0
        case .learningPlan: return 1.5
        case .podcast: return 1.5
        case .infographic: return 3.0
        }
    }

    /// Practical preflight estimate for the UI. The backend still computes the
    /// final charge, but this avoids showing optimistic floor prices.
    static func estimateMC(
        for kind: GeneratedKind,
        sourceCount: Int = 1,
        requestedCount: Int? = nil,
        quality: String? = nil
    ) -> Double {
        var mc: Double
        switch kind {
        case .summary: mc = 1.6
        case .examMorningSummary: mc = 2.1
        case .flashcard: mc = 1.8
        case .question: mc = 3.0
        case .algorithm: mc = 2.4
        case .comparison, .table: mc = 3.2
        case .mindMap: mc = 2.2
        case .clinicalScenario: mc = 4.0
        case .learningPlan: mc = 2.6
        case .podcast: mc = 3.4
        case .infographic: mc = 4.8
        }

        if let requestedCount {
            switch kind {
            case .flashcard:
                mc += Double(max(0, requestedCount - 10)) * 0.045
            case .question:
                mc += Double(max(0, requestedCount - 10)) * 0.085
            default:
                break
            }
        }

        let extraSourceCost: Double = {
            switch kind {
            case .comparison, .table:
                return 0.65
            case .clinicalScenario, .podcast, .infographic:
                return 0.5
            default:
                return 0.42
            }
        }()
        mc += Double(max(0, sourceCount - 1)) * extraSourceCost

        let qualityValue = (quality ?? "").lowercased()
        if qualityValue.contains("premium") {
            mc *= 1.45
        } else if qualityValue.contains("ekonomik") || qualityValue.contains("economy") {
            mc *= 0.85
        }

        return max(minMC(for: kind), (mc * 10).rounded(.up) / 10)
    }

    static func estimateLabel(
        for kind: GeneratedKind,
        sourceCount: Int = 1,
        requestedCount: Int? = nil,
        quality: String? = nil
    ) -> String {
        let low = estimateMC(for: kind, sourceCount: sourceCount, requestedCount: requestedCount, quality: quality)
        let high = max(low + 0.3, (low * 1.32 * 10).rounded(.up) / 10)
        return "Tahmini \(format(low))-\(format(high)) MC"
    }

    static func compactEstimate(
        for kind: GeneratedKind,
        sourceCount: Int = 1,
        requestedCount: Int? = nil,
        quality: String? = nil
    ) -> String {
        let mc = estimateMC(for: kind, sourceCount: sourceCount, requestedCount: requestedCount, quality: quality)
        return "≈ \(format(mc)) MC"
    }

    /// Student-facing label, e.g. "Tahmini 1,2-1,6 MC · son tutar üretimde netleşir".
    static func label(
        for kind: GeneratedKind,
        sourceCount: Int = 1,
        requestedCount: Int? = nil,
        quality: String? = nil
    ) -> String {
        "\(estimateLabel(for: kind, sourceCount: sourceCount, requestedCount: requestedCount, quality: quality)) · son tutar üretimde netleşir"
    }

    private static func format(_ mc: Double) -> String {
        mc.formatted(.number.precision(.fractionLength(0...1)))
    }

    static func minimumLabel(for kind: GeneratedKind) -> String {
        let mc = minMC(for: kind)
        let formatted = mc.formatted(.number.precision(.fractionLength(0...1)))
        return "En az \(formatted) MC · kaynağına göre artabilir"
    }
}
