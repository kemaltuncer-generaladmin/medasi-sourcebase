import SwiftUI
import SourceBaseBackend
import Supabase
import PhotosUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var profileSnapshot: ProfileSnapshot = .empty
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var profileLoadFailed = false
    @State private var isSigningOut = false
    @State private var showSignOutConfirm = false
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    
    private var router: AppRouter { appState.router }
    private var session: SessionStore { appState.session }
    private var profileName: String { session.displayName }
    private var profileEmail: String { session.email }
    private var needsProfileDetails: Bool { session.needsProfileSetup }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.lg) {
                if isLoading {
                    SBLoadingState(
                        icon: "person.crop.circle",
                        title: "Profil yükleniyor",
                        message: "Hesap ve üretim kredisi bilgilerin hazırlanıyor..."
                    )
                } else {
                    profileHeader.sbEntrance(0)
                    
                    if profileLoadFailed {
                        inlineNoticeCard(
                            icon: "exclamationmark.circle",
                            message: "Profil tablosu okunamadı. Auth bilgilerindeki güvenli yedekler gösteriliyor."
                        ).sbEntrance(1)
                    }

                    walletSection.sbEntrance(2)
                    settingsSection.sbEntrance(3)
                    logoutButton.sbEntrance(4)
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(1180)
        }
        .sbPageBackground()
        .navigationTitle("Profil")
        .sbOpaqueNavBar()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: .search)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .sbScaledFont(size: 18, weight: .bold)
                        .foregroundStyle(SBColors.navy)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .refreshable {
            await loadProfileData()
        }
        .task {
            await loadProfileData()
        }
        .confirmationDialog(
            "Oturumu Kapat",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Oturumu Kapat", role: .destructive) {
                Task {
                    await performSignOut()
                }
            }
            Button("Sürdür", role: .cancel) {}
        } message: {
            Text("Oturumunuzu kapatmak istediğinize emin misiniz? Devam etmek için yeniden giriş yapmanız gerekecektir.")
        }
    }
    
    // MARK: - Profile Header View
    
    private var profileHeader: some View {
        SBCard(radius: 20, borderColor: SBColors.blue.opacity(0.12)) {
            HStack(spacing: SBSpacing.md) {
                avatarPicker

                VStack(alignment: .leading, spacing: SBSpacing.xs) {
                    Text(profileName)
                        .font(SBTypography.heading3)
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(1)

                    Text(profileEmail)
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(1)

                    if needsProfileDetails {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .sbScaledFont(size: 10)
                                .foregroundStyle(SBColors.purple)
                            
                            Text("Profil eksik - Tamamla")
                                .font(SBTypography.caption)
                                .foregroundStyle(SBColors.purple)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SBColors.purple.opacity(0.1))
                        .clipShape(Capsule())
                    } else if !profileSnapshot.faculty.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "graduationcap")
                                .sbScaledFont(size: 12)
                                .foregroundStyle(SBColors.blue)
                            
                            Text(profileSnapshot.faculty)
                                .font(SBTypography.caption)
                                .foregroundStyle(SBColors.navy)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SBColors.selectedBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .layoutPriority(1)

                Spacer()

                Button {
                    SBHaptics.tap(.light)
                    router.navigate(to: .profileSetup)
                } label: {
                    Image(systemName: "pencil")
                        .sbScaledFont(size: 18)
                        .foregroundStyle(SBColors.blue)
                        .frame(width: 40, height: 40)
                        .background(SBColors.selectedBlue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profili düzenle")
            }
        }
        .onChange(of: selectedAvatarItem) { _, item in
            guard let item else { return }
            Task { await uploadAvatar(item) }
        }
    }

    @MainActor
    private var avatarPicker: some View {
        let avatarURL = profileSnapshot.avatarURL
        let uploading = isUploadingAvatar
        return PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
            ProfileAvatarPickerLabel(avatarURL: avatarURL, isUploading: uploading)
        }
        .buttonStyle(.plain)
        .disabled(isUploadingAvatar)
        .accessibilityLabel("Profil fotoğrafı")
        .accessibilityValue(isUploadingAvatar ? "Yükleniyor" : "Değiştirilebilir")
        .accessibilityHint("Yeni profil fotoğrafı seçer")
    }
    
    // MARK: - Inline Notice
    
    private func inlineNoticeCard(icon: String, message: String) -> some View {
        HStack(spacing: SBSpacing.sm) {
            Image(systemName: icon)
                .sbScaledFont(size: 16, weight: .bold)
                .foregroundStyle(SBColors.purple)
            
            Text(message)
                .font(SBTypography.caption)
                .foregroundStyle(SBColors.navy)
                .lineSpacing(1.3)
        }
        .padding(12)
        .background(SBColors.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Wallet / Balance Panel
    
    private var walletSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Text("Üretim kredisi")
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)
            
            SBCommandCard(tint: SBColors.green, action: {
                router.navigate(to: .store)
            }) {
                HStack(spacing: SBSpacing.md) {
                    SBIconTile(icon: "creditcard.fill", tint: SBColors.green, size: 50, radius: 14)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MC üretim kredisi")
                            .font(SBTypography.labelSmall)
                            .foregroundStyle(SBColors.muted)

                        if let walletBalance = profileSnapshot.walletBalance {
                            Text("\(walletBalance.formatted(.number.precision(.fractionLength(0...2)))) MC")
                                .font(SBTypography.heading2)
                                .foregroundStyle(SBColors.navy)
                        } else {
                            Text("Bakiye alınamadı")
                                .font(SBTypography.titleMedium)
                                .foregroundStyle(SBColors.softText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "plus")
                        .sbScaledFont(size: 15, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(SBColors.green)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - App Settings Sections
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Text("Ayarlar")
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)
            
            SBCard(radius: 16) {
                VStack(spacing: 0) {
                    settingsRow(
                        icon: "gearshape",
                        title: "Tüm Ayarlar",
                        description: "Görünüm, bildirim, depolama ve kalite durumunu açabilirsin."
                    ) {
                        router.navigate(to: .settings)
                    }

                    Divider()
                        .padding(.vertical, SBSpacing.xs)

                    settingsRow(
                        icon: "person",
                        title: "Profil Bilgileri",
                        description: "Fakülte, bölüm ve sınıf bilgilerini düzenleyebilirsin."
                    ) {
                        router.navigate(to: .profileSetup)
                    }
                    
                    Divider()
                        .padding(.vertical, SBSpacing.xs)
                    
                    settingsRow(
                        icon: "lock.shield",
                        title: "Güvenlik ve Şifre",
                        description: "Şifre yenileme ve oturum güvenliği bilgilerini görebilirsin."
                    ) {
                        router.navigate(to: .profileMenu(.security))
                    }
                    
                    Divider()
                        .padding(.vertical, SBSpacing.xs)

                    settingsRow(
                        icon: "paintpalette",
                        title: "Görünüm",
                        description: "Tema ve ekran tercihlerini kontrol edebilirsin."
                    ) {
                        router.navigate(to: .profileMenu(.appearance))
                    }

                    Divider()
                        .padding(.vertical, SBSpacing.xs)

                    settingsRow(
                        icon: "bell.badge",
                        title: "Bildirimler",
                        description: "Yükleme ve üretim hatırlatmalarını yönetebilirsin."
                    ) {
                        router.navigate(to: .profileMenu(.notifications))
                    }

                    Divider()
                        .padding(.vertical, SBSpacing.xs)

                    settingsRow(
                        icon: "internaldrive",
                        title: "Depolama",
                        description: "Drive kullanımı ve kaynak durumunu görebilirsin."
                    ) {
                        router.navigate(to: .profileMenu(.storage))
                    }

                    Divider()
                        .padding(.vertical, SBSpacing.xs)
                    
                    settingsRow(
                        icon: "eye.slash",
                        title: "Gizlilik ve Destek",
                        description: "Veri güvenliği ve resmi destek bilgilerini görebilirsin."
                    ) {
                        router.navigate(to: .profileMenu(.privacySupport))
                    }
                    
                    Divider()
                        .padding(.vertical, SBSpacing.xs)

                    settingsRow(
                        icon: "questionmark.circle",
                        title: "Yardım",
                        description: "Kullanım ve destek notlarını açabilirsin."
                    ) {
                        router.navigate(to: .profileMenu(.help))
                    }

                    Divider()
                        .padding(.vertical, SBSpacing.xs)

                    settingsRow(
                        icon: "info.circle",
                        title: "SourceBase Hakkında",
                        description: "Ürün kapsamını ve deneysel modu görebilirsin."
                    ) {
                        router.navigate(to: .profileMenu(.about))
                    }

                    Divider()
                        .padding(.vertical, SBSpacing.xs)
                    
                    settingsRow(
                        icon: "trash",
                        title: "Hesap Silme",
                        description: "Hesap silme talebi durumunu kontrol edebilirsin."
                    ) {
                        router.navigate(to: .profileMenu(.deleteAccount))
                    }
                }
            }
        }
    }
    
    private func settingsRow(icon: String, title: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SBSpacing.md) {
                Image(systemName: icon)
                    .sbScaledFont(size: 20)
                    .foregroundStyle(SBColors.blue)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SBTypography.labelSmall)
                        .foregroundStyle(SBColors.navy)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .sbScaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(SBColors.softText)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, SBSpacing.sm)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(description)
        .accessibilityHint("Detayı açar")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Logout Button
    
    private var logoutButton: some View {
        SBButton(
            isSigningOut ? "Oturum Kapatılıyor..." : "Oturumu Kapat",
            icon: "door.right.to.left.open",
            variant: .secondary,
            size: .medium,
            isLoading: isSigningOut,
            fullWidth: true,
            action: {
                showSignOutConfirm = true
            }
        )
        .padding(.top, SBSpacing.md)
    }
    
    // MARK: - Helpers
    
    private func performSignOut() async {
        isSigningOut = true
        await appState.signOut()
        isSigningOut = false
    }
    
    private func loadProfileData() async {
        isLoading = true
        errorMessage = nil
        profileLoadFailed = false
        
        do {
            if let client = await AuthBackend.shared.getClient() {
                guard let user = client.auth.currentUser else {
                    errorMessage = "Oturum bulunamadı."
                    isLoading = false
                    return
                }
                
                // Get workspace data to feed count metrics
                let driveRepo = DriveRepository(api: DriveAPI(client: client))
                let workspace = try await driveRepo.loadWorkspace()
                
                let profRepo = ProfileRepository(client: client)
                profileSnapshot = try await profRepo.loadProfile(userId: user.id.uuidString, workspace: workspace)
            } else {
                profileSnapshot = .empty
            }
        } catch {
            profileLoadFailed = true
            
            // Generate fallback data from Session description metadata safely
            profileSnapshot = ProfileSnapshot(
                displayName: session.displayName,
                email: session.email,
                faculty: session.currentUser?.userMetadata["sourcebase_faculty"]?.stringValue ?? "",
                department: session.currentUser?.userMetadata["sourcebase_department"]?.stringValue ?? "",
                className: session.currentUser?.userMetadata["sourcebase_class_year"]?.stringValue ?? "",
                walletBalance: nil,
                courseCount: 0,
                fileCount: 0,
                generatedCount: 0,
                collectionCount: 0,
                avatarURL: session.currentUser?.userMetadata["avatar_url"]?.stringValue
            )
        }
        
        isLoading = false
    }

    private func uploadAvatar(_ item: PhotosPickerItem) async {
        guard !isUploadingAvatar else { return }
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                workspaceStore.toast("Profil fotoğrafı okunamadı.")
                return
            }
            guard data.count <= 8_000_000 else {
                workspaceStore.toast("Profil fotoğrafı 8 MB altında olmalı.")
                return
            }
            guard let client = await AuthBackend.shared.getClient() else {
                workspaceStore.toast("Oturum doğrulanamadı.")
                return
            }
            let repo = ProfileRepository(client: client)
            let avatarURL = try await repo.uploadProfileAvatar(
                data: data,
                fileName: "sourcebase-avatar-\(UUID().uuidString).jpg",
                contentType: "image/jpeg"
            )
            _ = try? await AuthBackend.shared.updateAvatarURL(avatarURL)
            workspaceStore.toast("Profil fotoğrafın güncellendi.")
            await loadProfileData()
        } catch {
            workspaceStore.toast(workspaceStore.friendlyError(error))
        }
    }
}

private struct ProfileAvatarPickerLabel: View {
    let avatarURL: String?
    let isUploading: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(SBColors.primaryGradient)
                    .frame(width: 72, height: 72)

                if let avatarURL,
                   let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .sbScaledFont(size: 32)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .sbScaledFont(size: 32)
                        .foregroundStyle(.white)
                }
            }

            ZStack {
                Circle()
                    .fill(SBColors.blue)
                    .frame(width: 26, height: 26)
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.58)
                } else {
                    Image(systemName: "camera.fill")
                        .sbScaledFont(size: 12, weight: .bold)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environment(AppState.shared)
    }
}
