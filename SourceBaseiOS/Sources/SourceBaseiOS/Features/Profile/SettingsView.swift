import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @AppStorage(SBProfilePreferenceKey.appearance) private var appearance = SBAppearancePreference.system.rawValue
    @AppStorage(SBProfilePreferenceKey.sourceNotifications) private var sourceNotifications = true
    @AppStorage(SBProfilePreferenceKey.generationNotifications) private var generationNotifications = true
    @AppStorage(SBProfilePreferenceKey.compactCards) private var compactCards = false

    private var router: AppRouter { appState.router }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                SBPageHeader(
                    title: "Ayarlar",
                    subtitle: "Hesap, görünüm, bildirim ve uygulama bilgilerini yönetebilirsin.",
                    primaryIcon: "questionmark.circle",
                    onPrimary: { router.navigate(to: .profileMenu(.help)) }
                )

                accountSection
                appearanceSection
                notificationSection
                storageSection
                legalSection
                aboutSection
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(720)
        }
        .sbPageBackground()
        .sbInlineNavTitle()
        .sbBackButton { router.pop() }
        .task {
            await workspaceStore.loadWorkspace()
        }
    }

    private var accountSection: some View {
        settingsGroup(title: "Hesap") {
            settingsActionRow(
                icon: "person",
                title: "Profil bilgileri",
                detail: "Fakülte, dönem ve akademik bilgileri düzenle."
            ) {
                router.navigate(to: .profileSetup)
            }

            Divider().padding(.vertical, SBSpacing.xs)

            settingsActionRow(
                icon: "creditcard",
                title: "MC üretim kredisi",
                detail: "Kaynak tabanlı üretim bakiyesi ve paketleri görüntüle."
            ) {
                router.navigate(to: .store)
            }
        }
    }

    private var appearanceSection: some View {
        settingsGroup(title: "Görünüm") {
            Toggle(isOn: $compactCards) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Kompakt kart yoğunluğu")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)
                    Text("Uzun listelerde daha sıkı kart aralığı kullan.")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                }
            }
            .tint(SBColors.blue)

            Divider().padding(.vertical, SBSpacing.xs)

            VStack(alignment: .leading, spacing: SBSpacing.sm) {
                HStack(spacing: SBSpacing.md) {
                    Image(systemName: "moon.stars")
                        .sbScaledFont(size: 18, weight: .semibold)
                        .foregroundStyle(SBColors.blue)
                        .frame(width: 34, height: 34)
                        .background(SBColors.selectedBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tema")
                            .font(SBTypography.labelSmall)
                            .foregroundStyle(SBColors.navy)
                        Text("Görünüm tercihleri bu cihazda uygulanır.")
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                    }
                }

                Picker("Tema", selection: $appearance) {
                    ForEach(SBAppearancePreference.allCases) { preference in
                        Text(preference.title).tag(preference.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var notificationSection: some View {
        settingsGroup(title: "Bildirimler") {
            Toggle(isOn: $sourceNotifications) {
                settingsToggleLabel(
                    title: "Kaynak işleme",
                    detail: "Yükleme ve metin çıkarma durumları için bildirim al."
                )
            }
            .tint(SBColors.blue)

            Divider().padding(.vertical, SBSpacing.xs)

            Toggle(isOn: $generationNotifications) {
                settingsToggleLabel(
                    title: "Üretim tamamlanınca",
                    detail: "Kart, soru ve özet tamamlanınca haber ver."
                )
            }
            .tint(SBColors.blue)
        }
    }

    private var storageSection: some View {
        settingsGroup(title: "Depolama") {
            HStack(spacing: SBSpacing.sm) {
                SBMetricTile(icon: "doc.text", value: "\(workspaceStore.allFiles.count)", label: "Kaynak", tint: SBColors.blue)
                SBMetricTile(icon: "rectangle.stack", value: "\(workspaceStore.workspace.collections.count)", label: "Koleksiyon", tint: SBColors.purple)
            }

            SBNotice(
                icon: "internaldrive",
                message: "Drive kaynakların, çalışmaların ve koleksiyonların burada özetlenir.",
                tint: SBColors.cyan
            )
        }
    }

    private var legalSection: some View {
        settingsGroup(title: "Yasal") {
            legalLinkRow(icon: "hand.raised", title: "Gizlilik Politikası", url: SBLegalLinks.privacyURL)
            Divider().padding(.vertical, SBSpacing.xs)
            legalLinkRow(icon: "doc.text", title: "Kullanım Koşulları", url: SBLegalLinks.termsURL)
        }
    }

    private func legalLinkRow(icon: String, title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: SBSpacing.md) {
                Image(systemName: icon)
                    .sbScaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(SBColors.blue)
                    .frame(width: 34, height: 34)
                    .background(SBColors.selectedBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)

                Text(title)
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.navy)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .sbScaledFont(size: 12, weight: .bold)
                    .foregroundStyle(SBColors.softText)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), tarayıcıda aç")
    }

    private var aboutSection: some View {
        settingsGroup(title: "Yardım ve Hakkında") {
            settingsActionRow(
                icon: "questionmark.circle",
                title: "Yardım",
                detail: "Kaynak yükleme, üretim ve MC kullanımı için kısa notlar."
            ) {
                router.navigate(to: .profileMenu(.help))
            }

            Divider().padding(.vertical, SBSpacing.xs)

            settingsActionRow(
                icon: "info.circle",
                title: "SourceBase hakkında",
                detail: "Medasi ekosistemi için kaynak tabanlı öğrenme alanı."
            ) {
                router.navigate(to: .profileMenu(.about))
            }
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Text(title)
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)

            SBCard(radius: 16) {
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    content()
                }
            }
        }
    }

    private func settingsActionRow(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SBSpacing.md) {
                Image(systemName: icon)
                    .sbScaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(SBColors.blue)
                    .frame(width: 34, height: 34)
                    .background(SBColors.selectedBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)
                    Text(detail)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .sbScaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(SBColors.softText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsToggleLabel(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(SBTypography.labelSmall)
                .foregroundStyle(SBColors.navy)
            Text(detail)
                .font(SBTypography.caption)
                .foregroundStyle(SBColors.muted)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
