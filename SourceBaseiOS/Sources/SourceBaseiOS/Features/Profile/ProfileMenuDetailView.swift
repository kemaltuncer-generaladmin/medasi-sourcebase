import SwiftUI

public enum ProfileMenuDestination: String, Hashable {
    case security
    case appearance
    case notifications
    case storage
    case privacySupport
    case help
    case about
    case deleteAccount

    var title: String {
        switch self {
        case .security: return "Güvenlik ve Şifre"
        case .appearance: return "Görünüm"
        case .notifications: return "Bildirimler"
        case .storage: return "Depolama"
        case .privacySupport: return "Gizlilik ve Destek"
        case .help: return "Yardım"
        case .about: return "SourceBase Hakkında"
        case .deleteAccount: return "Hesap Silme"
        }
    }

    var subtitle: String {
        switch self {
        case .security: return "Şifre yenileme ve oturum güvenliği işlemlerini yönetebilirsin."
        case .appearance: return "Uygulama görünümünü ve ekran yoğunluğunu seçebilirsin."
        case .notifications: return "Hangi çalışma olaylarında bildirim almak istediğini belirle."
        case .storage: return "Drive alanındaki kaynak ve koleksiyonlarını görüntüleyebilirsin."
        case .privacySupport: return "Veri tercihlerini düzenle ve destek bilgilerine ulaş."
        case .help: return "En sık kullanılan SourceBase akışlarına hızlıca ulaş."
        case .about: return "SourceBase sürümü ve ürün kapsamını görüntüleyebilirsin."
        case .deleteAccount: return "Hesap silme isteğinin durumunu yönetebilirsin."
        }
    }

    var icon: String {
        switch self {
        case .security: return "lock.shield"
        case .appearance: return "paintpalette"
        case .notifications: return "bell.badge"
        case .storage: return "internaldrive"
        case .privacySupport: return "eye.slash"
        case .help: return "questionmark.circle"
        case .about: return "info.circle"
        case .deleteAccount: return "trash"
        }
    }
}

struct ProfileMenuDetailView: View {
    let destination: ProfileMenuDestination

    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @AppStorage(SBProfilePreferenceKey.appearance) private var appearance = SBAppearancePreference.system.rawValue
    @AppStorage(SBProfilePreferenceKey.compactCards) private var compactCards = false
    @AppStorage(SBProfilePreferenceKey.sourceNotifications) private var sourceNotifications = true
    @AppStorage(SBProfilePreferenceKey.generationNotifications) private var generationNotifications = true
    @AppStorage(SBProfilePreferenceKey.studyNotifications) private var studyNotifications = false
    @AppStorage(SBProfilePreferenceKey.analyticsSharing) private var analyticsSharing = false
    @State private var notice: ProfileNotice?
    @State private var showSignOutConfirmation = false
    @State private var showDeletionConfirmation = false
    @State private var isRequestingDeletion = false
    @State private var supportTopic = "Yükleme ve dosya işleme"
    @State private var supportEmail = ""
    @State private var supportMessage = ""
    @State private var isSubmittingSupport = false

    private var router: AppRouter { appState.router }
    private var session: SessionStore { appState.session }

    private enum ProfileNotice {
        case success(String)
        case error(String)

        var message: String {
            switch self {
            case .success(let message), .error(let message):
                return message
            }
        }

        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle"
            case .error:
                return "exclamationmark.triangle"
            }
        }

        var tint: Color {
            switch self {
            case .success:
                return SBColors.green
            case .error:
                return SBColors.red
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                SBPageHeader(
                    title: destination.title,
                    subtitle: destination.subtitle
                )

                if let notice {
                    SBNotice(icon: notice.icon, message: notice.message, tint: notice.tint)
                }

                detailContent
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(720)
        }
        .sbPageBackground()
        .navigationTitle(destination.title)
        .sbInlineNavTitle()
        .sbBackButton { router.pop() }
        .task {
            if destination == .storage {
                await workspaceStore.loadWorkspace()
            }
        }
        .confirmationDialog(
            "Oturumu kapat",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Oturumu kapat", role: .destructive) {
                Task { await appState.signOut() }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Devam etmek için yeniden giriş yapman gerekir.")
        }
        .confirmationDialog(
            "Hesap Silme Talebi",
            isPresented: $showDeletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Talebi Gönder ve Çıkış Yap", role: .destructive) {
                requestAccountDeletion()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu işlem silme talebini backend'e iletir. Profil, Drive ve üretim kredisi verilerinin silme süreci başlatılır ve oturumun kapatılır.")
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch destination {
        case .security:
            securityContent
        case .appearance:
            appearanceContent
        case .notifications:
            notificationsContent
        case .storage:
            storageContent
        case .privacySupport:
            privacyContent
        case .help:
            helpContent
        case .about:
            aboutContent
        case .deleteAccount:
            deleteAccountContent
        }
    }

    private var securityContent: some View {
        VStack(alignment: .leading, spacing: SBSpacing.lg) {
            infoCard(
                title: "Aktif Hesap",
                rows: [
                    ("E-posta", session.email.isEmpty ? "Oturum e-postası yok" : session.email),
                    ("Oturum", "Aktif")
                ]
            )

            SBNotice(
                icon: "key",
                message: "Şifre yenileme bağlantısı kayıtlı e-posta adresine gönderilir.",
                tint: SBColors.blue
            )

            SBButton("Şifre Yenileme Bağlantısı Gönder", icon: "envelope", fullWidth: true) {
                requestPasswordReset()
            }

            SBButton("Oturumu kapat", icon: "door.right.to.left.open", variant: .secondary, fullWidth: true) {
                showSignOutConfirmation = true
            }
        }
    }

    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: SBSpacing.lg) {
            settingsCard {
                VStack(alignment: .leading, spacing: SBSpacing.sm) {
                    Text("Tema")
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)
                    Picker("Tema", selection: $appearance) {
                        ForEach(SBAppearancePreference.allCases) { preference in
                            Text(preference.title).tag(preference.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider().padding(.vertical, SBSpacing.xs)

                Toggle("Kompakt kart yoğunluğu", isOn: $compactCards)
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.navy)
                    .tint(SBColors.blue)
            }

            SBNotice(
                icon: "paintpalette",
                message: "Tema ve kart yoğunluğu tercihlerin bu cihazda saklanır.",
                tint: SBColors.purple
            )
        }
    }

    private var notificationsContent: some View {
        settingsCard {
            preferenceToggle(
                title: "Kaynak işleme",
                detail: "Yükleme ve metin çıkarma durumları için bildirim al.",
                isOn: $sourceNotifications
            )
            Divider().padding(.vertical, SBSpacing.xs)
            preferenceToggle(
                title: "Üretim tamamlanınca",
                detail: "Kart, soru ve özet tamamlanınca haber ver.",
                isOn: $generationNotifications
            )
            Divider().padding(.vertical, SBSpacing.xs)
            preferenceToggle(
                title: "Çalışma hatırlatmaları",
                detail: "Planlanan çalışma akışları için hatırlatma al.",
                isOn: $studyNotifications
            )
        }
    }

    private var storageContent: some View {
        VStack(alignment: .leading, spacing: SBSpacing.lg) {
            HStack(spacing: SBSpacing.sm) {
                SBMetricTile(icon: "doc.text", value: "\(workspaceStore.allFiles.count)", label: "Kaynak", tint: SBColors.blue)
                SBMetricTile(icon: "rectangle.stack", value: "\(workspaceStore.workspace.collections.count)", label: "Koleksiyon", tint: SBColors.purple)
            }

            settingsCard {
                navigationRow(icon: "arrow.up.doc", title: "Yüklemeleri Görüntüle") {
                    router.navigate(to: .uploads)
                }
                Divider().padding(.vertical, SBSpacing.xs)
                navigationRow(icon: "rectangle.stack", title: "Koleksiyonları Görüntüle") {
                    router.navigate(to: .collections)
                }
            }
        }
    }

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: SBSpacing.lg) {
            settingsCard {
                preferenceToggle(
                    title: "Anonim kullanım verileri",
                    detail: "Ürün geliştirme için cihazdaki tercih durumunu sakla.",
                    isOn: $analyticsSharing
                )
            }

            SBNotice(
                icon: "lock.shield",
                message: "Dosya, profil ve üretim kredisi bilgileri oturum sahibi kullanıcıya ait çalışma alanında gösterilir. Ödeme onayı olmadan bakiye eklenmez.",
                tint: SBColors.green
            )

            navigationRow(icon: "questionmark.circle", title: "Yardım Akışını Aç") {
                router.navigate(to: .profileMenu(.help))
            }
        }
    }

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: SBSpacing.lg) {
            settingsCard {
                Text("Sık Sorulan Sorular")
                    .font(SBTypography.titleMedium)
                    .foregroundStyle(SBColors.navy)

                faqRow(
                    question: "PDF yükledim, neden işleniyor görünüyor?",
                    answer: "Metin çıkarımı tamamlanmadan kaynak üretime açılmaz. Taranmış/görsel PDF'lerde OCR gerektiği için açık hata gösterilir."
                )
                faqRow(
                    question: "Üretilen sorular nerede çözülür?",
                    answer: "Soru üretimi tamamlanınca doğrudan Qlinik tarzı çözüm ekranı açılır. Koleksiyonlardan aynı ekrana dönebilirsin."
                )
                faqRow(
                    question: "PDF çıktıyı nereden alırım?",
                    answer: "Sınav özeti, algoritma, karşılaştırma ve zihin haritası çalışma ekranlarında PDF dışa aktarımı bulunur."
                )
                faqRow(
                    question: "MC paketleri nasıl yüklenir?",
                    answer: "Paket ekranında App Store ödemesi başlatılır; onay sonrası MC bakiyesi profilinde görünür."
                )
            }

            settingsCard {
                Text("Destek Formu")
                    .font(SBTypography.titleMedium)
                    .foregroundStyle(SBColors.navy)

                Picker("Konu", selection: $supportTopic) {
                    ForEach([
                        "Yükleme ve dosya işleme",
                        "Üretim çıktıları",
                        "Ödeme ve paketler",
                        "Profil ve hesap",
                        "Diğer"
                    ], id: \.self) { topic in
                        Text(topic).tag(topic)
                    }
                }
                .pickerStyle(.menu)
                .tint(SBColors.blue)

                TextField("E-posta", text: $supportEmail)
                    .font(SBTypography.bodyMedium)
                    .padding(SBSpacing.md)
                    .background(SBColors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                TextField("Mesajını yaz", text: $supportMessage, axis: .vertical)
                    .lineLimit(4...8)
                    .font(SBTypography.bodyMedium)
                    .padding(SBSpacing.md)
                    .background(SBColors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SBButton(
                    isSubmittingSupport ? "Gönderiliyor..." : "Formu Gönder",
                    icon: "paperplane",
                    isLoading: isSubmittingSupport,
                    fullWidth: true
                ) {
                    submitSupport()
                }
            }

            settingsCard {
                navigationRow(icon: "arrow.up.doc", title: "Kaynak Yüklemelerini Aç") {
                    router.navigate(to: .uploads)
                }
                Divider().padding(.vertical, SBSpacing.xs)
                navigationRow(icon: "wand.and.stars", title: "Üretim İçin Kaynak Seç") {
                    router.navigate(to: .sourcePicker)
                }
                Divider().padding(.vertical, SBSpacing.xs)
                navigationRow(icon: "creditcard", title: "MC Paketlerini Görüntüle") {
                    router.navigate(to: .store)
                }
            }
        }
    }

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: SBSpacing.lg) {
            infoCard(
                title: "Uygulama Bilgisi",
                rows: [
                    ("Ürün", "SourceBase"),
                    ("Sürüm", appVersion),
                    ("Alan", "Medasi öğrenme ekosistemi")
                ]
            )

            SBNotice(
                icon: "info.circle",
                message: "SourceBase, Medasi içinde kişisel kaynaklarını canlı çalışma materyaline dönüştüren premium öğrenme alanıdır. Drive kaynakları, BaseForce üretimleri, SourceLab şablonları ve MedasiChat aynı çalışma bağlamını paylaşır.",
                tint: SBColors.blue
            )

            settingsCard {
                Text("Neler yapar?")
                    .font(SBTypography.titleMedium)
                    .foregroundStyle(SBColors.navy)
                aboutBullet("PDF, PPTX, DOCX, PPT ve DOC kaynaklarını ders-bölüm düzeninde saklar.")
                aboutBullet("Flashcard, Qlinik formatlı soru, sınav sabahı özeti, algoritma, karşılaştırma ve zihin haritası üretir.")
                aboutBullet("Özel çalışma ekranları ve Medasi PDF şablonlarıyla çıktıyı okunabilir çalışma materyaline taşır.")
                aboutBullet("MC üretim kredisi ve MedasiChat akışıyla ortak profil deneyimi sunar.")
            }
        }
    }

    private var deleteAccountContent: some View {
        VStack(alignment: .leading, spacing: SBSpacing.lg) {
            SBNotice(
                icon: "exclamationmark.triangle",
                message: "Hesap silme talebi geri alınamaz. Profil, Drive verilerin, çalışma materyallerin ve üretim kredisi kayıtların silme sürecine alınır.",
                tint: SBColors.warning
            )

            SBNotice(
                icon: "info.circle",
                message: "Talep iletildikten sonra otomatik olarak çıkış yapılır. Hesap silme süreci kayıtlı e-posta adresine bildirilir.",
                tint: SBColors.blue
            )

            SBButton(
                isRequestingDeletion ? "Talep Gönderiliyor..." : "Hesap Silme Talebi Gönder",
                icon: "trash",
                variant: .secondary,
                isLoading: isRequestingDeletion,
                fullWidth: true
            ) {
                showDeletionConfirmation = true
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func requestPasswordReset() {
        guard !session.email.isEmpty else {
            notice = .error("Şifre yenileme için hesap e-postası bulunamadı.")
            return
        }

        notice = nil
        session.clearMessages()
        Task {
            await session.sendPasswordReset(email: session.email)
            if let success = session.successMessage, !success.isEmpty {
                notice = .success(success)
            } else if let error = session.errorMessage, !error.isEmpty {
                notice = .error(error)
            } else {
                notice = .success("Şifre yenileme bağlantısı gönderildi.")
            }
        }
    }

    private func requestAccountDeletion() {
        guard !isRequestingDeletion else { return }
        isRequestingDeletion = true
        Task {
            let ok = await workspaceStore.requestAccountDeletion()
            isRequestingDeletion = false
            if ok {
                // Sign out immediately after deletion request — Apple requirement
                await appState.signOut()
            } else {
                notice = .error(workspaceStore.toastMessage ?? "Talep gönderilemedi. Lütfen tekrar dene.")
            }
        }
    }

    private func submitSupport() {
        guard !isSubmittingSupport else { return }
        if supportEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            supportEmail = session.email
        }
        isSubmittingSupport = true
        Task {
            let ok = await workspaceStore.submitSupportForm(
                topic: supportTopic,
                email: supportEmail,
                message: supportMessage
            )
            if ok {
                notice = .success("Destek formun alındı.")
                supportMessage = ""
            } else {
                notice = .error(workspaceStore.toastMessage ?? "Destek formu gönderilemedi. Lütfen tekrar dene.")
            }
            isSubmittingSupport = false
        }
    }

    private func infoCard(title: String, rows: [(String, String)]) -> some View {
        settingsCard {
            Text(title)
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)

            ForEach(rows, id: \.0) { label, value in
                Divider().padding(.vertical, SBSpacing.xs)
                HStack {
                    Text(label)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                    Spacer()
                    Text(value)
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.sm) {
                content()
            }
        }
    }

    private func preferenceToggle(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.navy)
                Text(detail)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.muted)
            }
        }
        .tint(SBColors.blue)
    }

    private func navigationRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SBSpacing.md) {
                Image(systemName: icon)
                    .sbScaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(SBColors.blue)
                    .frame(width: 34, height: 34)
                    .background(SBColors.selectedBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(title)
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.navy)

                Spacer()

                Image(systemName: "chevron.right")
                    .sbScaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(SBColors.softText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func faqRow(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: SBSpacing.xs) {
            Divider().padding(.vertical, SBSpacing.xs)
            Text(question)
                .font(SBTypography.labelSmall)
                .foregroundStyle(SBColors.navy)
            Text(answer)
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func aboutBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: SBSpacing.sm) {
            Circle()
                .fill(SBColors.blue)
                .frame(width: 6, height: 6)
                .padding(.top, 7)
            Text(text)
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.navy)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileMenuDetailView(destination: .notifications)
            .environment(AppState.shared)
            .environment(SourceBaseWorkspaceStore.shared)
    }
}
