import SwiftUI

struct CentralAIView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                hero
                previewConversation
                readinessStrip
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(920)
        }
        .sbPageBackground(tone: .warm)
        .navigationTitle("MedasiChat")
        .sbOpaqueNavBar()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: SBSpacing.lg) {
            HStack(alignment: .top, spacing: SBSpacing.lg) {
                chatGlyph

                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    Text("MEDASICHAT")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.blue)

                    Text("Çok yakında aktifleşecek")
                        .font(SBTypography.display2)
                        .foregroundStyle(SBColors.navy)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("SourceBase kaynaklarınla aynı çalışma alanında, MedAsi ekosistemiyle uyumlu sohbet deneyimi hazırlanıyor.")
                        .font(SBTypography.bodyMedium)
                        .foregroundStyle(SBColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: SBSpacing.sm) {
                statusPill(icon: "checkmark.seal.fill", text: "Tasarım hazır", tint: SBColors.green)
                statusPill(icon: "bolt.fill", text: "Entegrasyon sırada", tint: SBColors.orange)
            }
        }
        .padding(SBSpacing.lg)
        .background(
            LinearGradient(
                colors: [SBColors.white, SBColors.selectedBlue.opacity(0.72), SBColors.greenBg.opacity(0.46)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(SBColors.blue.opacity(0.12), lineWidth: 1)
        )
    }

    private var chatGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(SBColors.navy)
                .frame(width: 92, height: 92)

            Circle()
                .fill(SBColors.blue.opacity(0.28))
                .frame(width: 72, height: 72)
                .offset(x: 18, y: -18)

            Image(systemName: "text.bubble.fill")
                .sbScaledFont(size: 34, weight: .semibold)
                .foregroundStyle(.white)

            Image(systemName: "sparkles")
                .sbScaledFont(size: 16, weight: .bold)
                .foregroundStyle(SBColors.green)
                .offset(x: 28, y: -28)
        }
        .accessibilityHidden(true)
    }

    private var previewConversation: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            Text("Önizleme")
                .font(SBTypography.titleSmall)
                .foregroundStyle(SBColors.navy)

            VStack(spacing: SBSpacing.sm) {
                chatBubble(
                    "Dahiliye notlarımdan bugün hangi konuları tekrar etmeliyim?",
                    isUser: true,
                    tint: SBColors.blue,
                    foreground: .white
                )
                chatBubble(
                    "Hazır olduğunda kaynaklarına göre kısa tekrar planı, zayıf nokta ve klinik soru önerilerini aynı ekranda toparlayacak.",
                    isUser: false,
                    tint: SBColors.greenBg,
                    foreground: SBColors.navy
                )
            }
        }
        .padding(SBSpacing.lg)
        .background(SBColors.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(SBColors.softLine, lineWidth: 1)
        )
    }

    private var readinessStrip: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: SBSpacing.md)], spacing: SBSpacing.md) {
            readinessItem(icon: "folder.fill", title: "Drive bağlamı", tint: SBColors.blue)
            readinessItem(icon: "graduationcap.fill", title: "Profil uyumu", tint: SBColors.purple)
            readinessItem(icon: "shield.lefthalf.filled", title: "Güvenli cevap", tint: SBColors.green)
        }
    }

    private func chatBubble(
        _ text: String,
        isUser: Bool,
        tint: Color,
        foreground: Color
    ) -> some View {
        HStack {
            if isUser { Spacer(minLength: 36) }
            Text(text)
                .font(SBTypography.bodyMedium)
                .foregroundStyle(foreground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SBSpacing.md)
                .padding(.vertical, SBSpacing.sm)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !isUser { Spacer(minLength: 36) }
        }
    }

    private func statusPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .sbScaledFont(size: 12, weight: .semibold)
            Text(text)
                .font(SBTypography.caption)
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    private func readinessItem(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: SBSpacing.sm) {
            Image(systemName: icon)
                .sbScaledFont(size: 17, weight: .semibold)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(title)
                .font(SBTypography.labelMedium)
                .foregroundStyle(SBColors.navy)
                .lineLimit(1)
        }
        .padding(SBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SBColors.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SBColors.softLine, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        CentralAIView()
    }
}
