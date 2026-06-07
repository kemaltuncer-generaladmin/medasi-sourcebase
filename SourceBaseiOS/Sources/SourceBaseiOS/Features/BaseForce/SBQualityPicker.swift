import SwiftUI

/// Shared quality tier used by every generation surface. The user picks the
/// tier; the backend treats it as authoritative for both the model and the
/// MedasiCoin cost (economy = cheapest, premium = best). The Turkish `rawValue`
/// is what flows into the generation `mode` string, where
/// `SourceBaseGenerationContract` maps it back to economy/standard/premium.
public enum SBQualityTier: String, CaseIterable, Sendable {
    case economy = "Ekonomik"
    case standard = "Standart"
    case premium = "Premium"

    /// Backend tier token.
    public var tier: String {
        switch self {
        case .economy: return "economy"
        case .standard: return "standard"
        case .premium: return "premium"
        }
    }

    public var icon: String {
        switch self {
        case .economy: return "leaf"
        case .standard: return "checkmark.seal"
        case .premium: return "crown"
        }
    }

    public var subtitle: String {
        switch self {
        case .economy: return "En düşük MC • hızlı"
        case .standard: return "Dengeli MC • kaliteli"
        case .premium: return "En yüksek MC • en iyi"
        }
    }
}

struct SBQualityPicker: View {
    @Binding var selection: SBQualityTier
    var accent: Color = SBColors.blue

    var body: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Text("Kalite")
                .font(SBTypography.labelSmall)
                .foregroundStyle(SBColors.navy)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120), spacing: SBSpacing.sm)],
                spacing: SBSpacing.sm
            ) {
                ForEach(SBQualityTier.allCases, id: \.self) { tier in
                    Button {
                        selection = tier
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: tier.icon)
                                    .sbScaledFont(size: 13, weight: .semibold)
                                Text(tier.rawValue)
                                    .font(SBTypography.caption)
                            }
                            .foregroundStyle(selection == tier ? .white : SBColors.navy)
                            Text(tier.subtitle)
                                .font(SBTypography.labelSmall)
                                .foregroundStyle(selection == tier ? Color.white.opacity(0.85) : SBColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, SBSpacing.md)
                        .padding(.horizontal, SBSpacing.sm)
                        .background(selection == tier ? accent : SBColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: BaseForceFactoryStyle.controlRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: BaseForceFactoryStyle.controlRadius)
                                .stroke(selection == tier ? accent : SBColors.softLine, lineWidth: 1)
                        )
                    }
                    .accessibilityLabel("\(tier.rawValue) kalite")
                    .accessibilityValue(selection == tier ? "Seçili" : "Seçili değil")
                    .accessibilityHint(tier.subtitle)
                }
            }
        }
    }
}
