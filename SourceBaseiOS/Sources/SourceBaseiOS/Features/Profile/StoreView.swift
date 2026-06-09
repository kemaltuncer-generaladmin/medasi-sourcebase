import SwiftUI
import StoreKit
import SourceBaseBackend

struct StoreView: View {
    @Environment(AppState.self) private var appState
    @State private var packages: [MedasiCoinPackage] = []
    @State private var walletBalance: Double?
    @State private var walletStatusMessage: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
#if DEBUG
    @State private var storeKitStatusMessage: String?
#endif

    // Per-package purchase states
    @State private var buyingPackageCode: String?
    @State private var purchaseStatusPackageCode: String?
    @State private var buyError: String?
    @State private var buyInfo: String?

    // Restore state
    @State private var isRestoring = false
    @State private var restoreNotice: StoreNotice?

    // Storage subscriptions
    @State private var storageStatus: SBStorageStatus?
    @State private var buyingStorageId: String?
    @State private var storageError: String?
    @State private var storageInfo: String?
    @State private var pendingDowngrade: SBStorageProduct?

    @Environment(\.openURL) private var openURL

    private var storeKit: SBStoreKitManager { SBStoreKitManager.shared }
    private var router: AppRouter { appState.router }

    /// The user's single active storage tier (cascade: at most one).
    private var activeStoragePlan: SBStorageProduct? {
        if let code = storageStatus?.plans.first?.productCode,
           let plan = SBStorageProduct(rawValue: code) {
            return plan
        }
        if let bonus = storageStatus?.bonusBytes, bonus > 0 {
            return SBStorageProduct.allCases.first { $0.bonusBytes == bonus }
        }
        return nil
    }

    private enum StoreNotice {
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
                premiumHeroCard
#if DEBUG
                storeKitDebugNotice
#endif
                walletSummarySection

                storageSection

                if isLoading {
                    SBLoadingState(
                        icon: "storefront",
                        title: "Paketler yükleniyor",
                        message: "MC üretim kredisi paketleri hazırlanıyor..."
                    )
                } else if let error = errorMessage, !error.isEmpty && packages.isEmpty {
                    SBErrorState(
                        title: "Paketler yüklenemedi",
                        message: error,
                        actionLabel: "Tekrar dene",
                        onAction: { Task { await loadStoreData() } }
                    )
                } else {
                    packagesSection
                    restoreSection
                }
            }
            .padding(SBSpacing.lg)
            .sbFloatingTabContentPadding()
            .sbReadableWidth(720)
        }
        .sbPageBackground()
        .navigationTitle("MC Paketleri")
        .sbInlineNavTitle()
        .sbBackButton { router.pop() }
        .refreshable { await loadStoreData() }
        .task { await loadStoreData() }
    }

    // MARK: - Premium Hero Card

    private var premiumHeroCard: some View {
        SBCard(radius: 20, backgroundColor: SBColors.white, showShadow: true) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack {
                    Text("MC Paketleri")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(SBColors.selectedBlue)
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "creditcard")
                        .sbScaledFont(size: 24)
                        .foregroundStyle(SBColors.blue)
                        .accessibilityHidden(true)
                }

                Text("MC üretim kredisi")
                    .font(SBTypography.heading2)
                    .foregroundStyle(SBColors.navy)

                Text("Çalışmalar MC ile hazırlanır. Paket satın alarak üretim bakiyeni artırabilirsin.")
                    .font(SBTypography.bodyMedium)
                    .foregroundStyle(SBColors.muted)
                    .lineSpacing(2)

                Divider().padding(.vertical, SBSpacing.xs)

                HStack(spacing: SBSpacing.md) {
                    metricInfo(icon: "applelogo", value: "App Store", label: "Ödeme")
                    metricInfo(icon: "shield.checkered", value: "Güvenli", label: "Ödeme")
                    metricInfo(icon: "iphone", value: "iOS", label: "Platform")
                }
            }
            .padding(SBSpacing.sm)
        }
    }

    private func metricInfo(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .sbScaledFont(size: 12)
                    .foregroundStyle(SBColors.blue)
                    .accessibilityHidden(true)
                Text(label)
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.softText)
            }
            Text(value)
                .font(SBTypography.labelSmall)
                .foregroundStyle(SBColors.navy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Wallet Balance

    private var walletSummarySection: some View {
        SBCard(radius: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MC bakiyesi")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)

                    if let balance = walletBalance {
                        Text("\(balance.formatted(.number.precision(.fractionLength(0...2)))) MC")
                            .font(SBTypography.heading2)
                            .foregroundStyle(SBColors.navy)
                    } else {
                        Text(walletStatusMessage ?? "Yükleniyor...")
                            .font(SBTypography.titleMedium)
                            .foregroundStyle(SBColors.softText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }

                Spacer()

                Button {
                    Task { await fetchWallet() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .accessibilityHidden(true)
                        Text("Yenile")
                    }
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(SBColors.selectedBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("Bakiyeyi yenile")
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Packages Section

    private var packagesSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            Text("Paketler")
                .font(SBTypography.titleMedium)
                .foregroundStyle(SBColors.navy)

            ForEach(packages) { package in
                packageTile(package)
            }
        }
    }

    private func packageTile(_ package: MedasiCoinPackage) -> some View {
        let isBuying = buyingPackageCode == package.code
        let hasStatus = purchaseStatusPackageCode == package.code
        let skProduct = storeKit.product(id: package.appStoreProductId)
        let priceDisplay = tlPrice(skProduct, fallback: package.priceLabel)
        let isBestValue = package.coin >= 200
        let purchaseLabel = "\(package.coin) MC satın al"

        return SBCard(radius: 16) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: SBSpacing.xs) {
                        if isBestValue {
                            packageBadge("Sık kullanılan")
                        }
                        Text(package.title)
                            .font(SBTypography.titleMedium)
                            .foregroundStyle(SBColors.navy)
                            .fontWeight(.bold)

                        Text(package.description)
                            .font(SBTypography.bodySmall)
                            .foregroundStyle(SBColors.muted)
                            .lineSpacing(1.5)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(SBColors.selectedBlue)
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .sbScaledFont(size: 16, weight: .bold)
                            .foregroundStyle(SBColors.blue)
                    }
                    .accessibilityHidden(true)
                }

                Text(priceDisplay)
                    .font(SBTypography.heading2)
                    .foregroundStyle(SBColors.navy)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    packageChip(icon: "toll", label: "\(package.coin) MC")
                    if package.coin > 0 && package.priceCents > 0 {
                        let priceUnit = Double(package.priceCents) / 100.0 / Double(package.coin)
                        packageChip(icon: "tag", label: "\(String(format: "%.2f", priceUnit)) \(package.currencyDisplay)/MC")
                    }
                }

                packageFeature("Ödeme App Store üzerinden işlenir")
                packageFeature("Onaylandığında MC bakiyene eklenir")

                // Per-package status notice
                if hasStatus {
                    if let info = buyInfo {
                        paymentNotice(icon: "checkmark.circle", color: SBColors.green, message: info)
                    } else if let error = buyError {
                        paymentNotice(icon: "exclamationmark.triangle", color: SBColors.red, message: error)
                    }
                }

                SBButton(
                    isBuying ? "Onay bekleniyor..." : purchaseLabel,
                    icon: "bag",
                    variant: .primary,
                    size: .medium,
                    isLoading: isBuying || storeKit.isPurchasing,
                    fullWidth: true,
                    action: { Task { await startPurchase(package: package) } }
                )
                .disabled(storeKit.isPurchasing)
                .accessibilityLabel(isBuying ? "\(package.title) paketi için satın alma işleniyor" : "\(package.title) paketini \(priceDisplay) karşılığında satın al")
                .accessibilityValue("\(package.coin) MC")
                .accessibilityHint("Ödeme App Store üzerinden onaylanır")
                .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Restore Section

    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Button {
                Task { await restorePurchases() }
            } label: {
                HStack(spacing: SBSpacing.sm) {
                    if isRestoring {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: SBColors.blue))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.counterclockwise")
                            .sbScaledFont(size: 14, weight: .semibold)
                            .accessibilityHidden(true)
                    }
                    Text(isRestoring ? "Geri yükleniyor..." : "Satın almalarımı geri yükle")
                        .font(SBTypography.labelSmall)
                }
                .foregroundStyle(SBColors.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SBSpacing.md)
            }
            .disabled(isRestoring)
            .accessibilityLabel("Satın almalarımı geri yükle")

            if let restoreNotice {
                paymentNotice(icon: restoreNotice.icon, color: restoreNotice.tint, message: restoreNotice.message)
            }
        }
    }

    // MARK: - Helper Views

    private func packageBadge(_ label: String) -> some View {
        Text(label)
            .font(SBTypography.caption)
            .foregroundStyle(SBColors.white)
            .fontWeight(.bold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(SBColors.blue)
            .clipShape(Capsule())
    }

    private func packageChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .sbScaledFont(size: 12, weight: .semibold)
                .accessibilityHidden(true)
            Text(label)
                .font(SBTypography.labelSmall)
        }
        .foregroundStyle(SBColors.navy)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(SBColors.selectedBlue)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func packageFeature(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(SBColors.selectedBlue)
                    .frame(width: 18, height: 18)
                Image(systemName: "checkmark")
                    .sbScaledFont(size: 10, weight: .bold)
                    .foregroundStyle(SBColors.blue)
            }
            .accessibilityHidden(true)
            Text(text)
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.navy)
                .lineSpacing(1.3)
        }
    }

    private func paymentNotice(icon: String, color: Color, message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .sbScaledFont(size: 15, weight: .semibold)
                .foregroundStyle(color)
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text(message)
                .font(SBTypography.bodySmall)
                .foregroundStyle(SBColors.navy)
                .lineSpacing(1.2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.18), lineWidth: 1))
    }

#if DEBUG
    @ViewBuilder
    private var storeKitDebugNotice: some View {
        if let storeKitStatusMessage {
            paymentNotice(
                icon: "shippingbox.and.arrow.backward",
                color: SBColors.purple,
                message: storeKitStatusMessage
            )
        }
    }
#endif

    // MARK: - Data Loaders

    private func loadStoreData() async {
        isLoading = true
        errorMessage = nil
#if DEBUG
        storeKitStatusMessage = nil
#endif

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await fetchPackages() }
            group.addTask { await fetchWallet() }
            group.addTask { await fetchStorageStatus() }
        }

        // Load StoreKit products for the MC packages AND the storage subscriptions.
        let ids = Set(packages.map(\.appStoreProductId)).union(SBStorageProduct.allProductIds)
        if !ids.isEmpty {
            do {
                try await storeKit.loadProducts(ids: ids)
#if DEBUG
                if storeKit.products.count < ids.count {
                    storeKitStatusMessage = "\(storeKit.products.count)/\(ids.count) App Store ürünü hazır. Eksik paketler satın alma sırasında kullanılamaz."
                }
#endif
            } catch {
#if DEBUG
                storeKitStatusMessage = "App Store ürünleri şu anda yüklenemedi."
#endif
            }
        }

        isLoading = false
    }

    private func fetchWallet() async {
        walletBalance = nil
        walletStatusMessage = "Yükleniyor..."
        do {
            guard let client = await AuthBackend.shared.getClient(),
                  let userId = client.auth.currentUser?.id.uuidString else {
                walletStatusMessage = "Oturum doğrulanamadı"
                return
            }
            let snapshot = try await ProfileRepository(client: client).loadProfile(
                userId: userId,
                workspace: appState.workspace.workspace
            )
            walletBalance = snapshot.walletBalance
            walletStatusMessage = snapshot.walletBalance == nil ? "Bakiye alınamadı" : nil
        } catch {
            walletBalance = nil
            walletStatusMessage = "Bakiye alınamadı"
        }
    }

    private func fetchPackages() async {
        do {
            guard let client = await AuthBackend.shared.getClient() else {
                packages = []
                errorMessage = "Mağaza için oturum doğrulanamadı."
                return
            }
            let products = try await StoreRepository(client: client).loadProducts()
            packages = products
                .map { MedasiCoinPackage(snapshot: $0) }
                .filter { $0.isConsumableCoinPack }
            if packages.isEmpty {
                errorMessage = "Mağaza paketleri şu anda listelenemiyor."
            }
        } catch {
            packages = []
            errorMessage = "Paketler şu anda alınamadı. Biraz sonra tekrar deneyebilirsin."
        }
    }

    // MARK: - Purchase Flow

    private func startPurchase(package: MedasiCoinPackage) async {
        guard let skProduct = storeKit.product(id: package.appStoreProductId) else {
            buyingPackageCode = nil
            purchaseStatusPackageCode = package.code
#if DEBUG
            buyError = "Bu paket şu anda App Store'dan yüklenemedi. Tekrar deneyebilirsin."
#else
            buyError = "Bu paket şu anda App Store'dan yüklenemedi. Tekrar deneyebilirsin."
#endif
            return
        }

        buyingPackageCode = package.code
        purchaseStatusPackageCode = nil
        buyError = nil
        buyInfo = nil

        do {
            try await storeKit.purchase(skProduct)
            purchaseStatusPackageCode = package.code
            buyInfo = "Satın alma tamamlandı! MC bakiyen güncellendi."
            buyingPackageCode = nil
            await fetchWallet()
        } catch SBStoreError.cancelled {
            // User cancelled — clear state silently
            buyingPackageCode = nil
            purchaseStatusPackageCode = nil
        } catch SBStoreError.pending {
            purchaseStatusPackageCode = package.code
            buyInfo = (SBStoreError.pending.errorDescription ?? "")
            buyingPackageCode = nil
        } catch SBStoreError.alreadyProcessing {
            purchaseStatusPackageCode = package.code
            buyInfo = (SBStoreError.alreadyProcessing.errorDescription ?? "")
            buyingPackageCode = nil
        } catch {
            purchaseStatusPackageCode = package.code
            buyError = error.localizedDescription.isEmpty
                ? "Satın alma tamamlanamadı. Tekrar deneyebilirsin."
                : error.localizedDescription
            buyingPackageCode = nil
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        restoreNotice = nil
        defer { isRestoring = false }
        do {
            try await storeKit.restore()
            await fetchWallet()
            await fetchStorageStatus()
            restoreNotice = .success("App Store eşitlemesi tamamlandı. Varsa bekleyen satın almalar bakiyene yansıtıldı.")
        } catch {
            restoreNotice = .error(
                error.localizedDescription.isEmpty
                    ? "Satın almalar geri yüklenemedi. Biraz sonra tekrar deneyebilirsin."
                    : error.localizedDescription
            )
        }
    }

    // MARK: - Storage

    @ViewBuilder
    private var storageSection: some View {
        let storageProducts = SBStorageProduct.allCases.filter { storeKit.product(id: $0.productId) != nil }
        if storageStatus != nil || !storageProducts.isEmpty {
            SBCard(radius: 18) {
                VStack(alignment: .leading, spacing: SBSpacing.md) {
                    HStack(spacing: SBSpacing.sm) {
                        Image(systemName: "externaldrive.badge.plus")
                            .sbScaledFont(size: 18, weight: .semibold)
                            .foregroundStyle(SBColors.blue)
                        Text("Depolama")
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                        Spacer()
                    }

                    if let storageStatus {
                        storageUsageBar(storageStatus)
                    }

                    Text("Aylık abonelikle depolama kotanı artır. Tek plan aktif olur. Yükseltme hemen geçerli olur; düşürme ve iptal App Store kuralı gereği mevcut dönem sonunda devreye girer, o zamana kadar şu anki paketin devam eder.")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(storageProducts) { product in
                        storageTile(product)
                    }

                    if activeStoragePlan != nil {
                        Button {
                            if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                openURL(url)
                            }
                        } label: {
                            HStack(spacing: SBSpacing.xs) {
                                Image(systemName: "gearshape")
                                    .sbScaledFont(size: 13, weight: .semibold)
                                Text("Aboneliği yönet")
                                    .font(SBTypography.labelSmall)
                            }
                            .foregroundStyle(SBColors.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    if let storageInfo {
                        Text(storageInfo)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.green)
                    } else if let storageError {
                        SBInlineError(message: storageError, isWarning: true)
                    }
                }
            }
            .alert(
                "Paketi düşür",
                isPresented: Binding(
                    get: { pendingDowngrade != nil },
                    set: { if !$0 { pendingDowngrade = nil } }
                ),
                presenting: pendingDowngrade
            ) { product in
                Button("Vazgeç", role: .cancel) { pendingDowngrade = nil }
                Button("Onayla") {
                    pendingDowngrade = nil
                    Task { await purchaseStorage(product, isDowngrade: true) }
                }
            } message: { product in
                Text(downgradeMessage(to: product))
            }
        }
    }

    private func storageUsageBar(_ status: SBStorageStatus) -> some View {
        let barColor: Color = status.isOverQuota ? SBColors.red : (status.isNearlyFull ? SBColors.orange : SBColors.blue)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(byteString(status.usedBytes)) / \(byteString(status.totalBytes))")
                    .font(SBTypography.labelMedium)
                    .foregroundStyle(SBColors.navy)
                Spacer()
                if status.bonusBytes > 0 {
                    Text("+\(byteString(status.bonusBytes)) abonelik")
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.green)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(SBColors.field)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(4, geo.size.width * status.usedFraction))
                }
            }
            .frame(height: 8)

            if status.isOverQuota {
                Label("Kotan aşıldı. Mevcut dosyaların korunur ama yeni yükleme için plan yükselt veya dosya sil.", systemImage: "exclamationmark.triangle.fill")
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if status.isNearlyFull {
                Label("Depolaman neredeyse doldu. Plan yükselterek yer açabilirsin.", systemImage: "exclamationmark.circle")
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func storageTile(_ product: SBStorageProduct) -> some View {
        let skProduct = storeKit.product(id: product.productId)
        let priceLabel = tlPrice(skProduct, fallback: product.fallbackPriceLabel)
        let isBuying = buyingStorageId == product.id
        let active = activeStoragePlan
        let isCurrent = active == product
        let isUpgrade = active.map { product.rank > $0.rank } ?? false
        let actionLabel: String = {
            if active == nil { return priceLabel }
            return isUpgrade ? "Yükselt" : "Düşür"
        }()
        let borderColor = isCurrent ? SBColors.green.opacity(0.55) : SBColors.softLine

        return HStack(spacing: SBSpacing.md) {
            Image(systemName: product.icon)
                .sbScaledFont(size: 20, weight: .semibold)
                .foregroundStyle(isCurrent ? SBColors.green : SBColors.blue)
                .frame(width: 40, height: 40)
                .background((isCurrent ? SBColors.green : SBColors.blue).opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: SBSpacing.xs) {
                    Text("\(product.gbLabel) / ay")
                        .font(SBTypography.titleSmall)
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if !isCurrent {
                        Text(priceLabel)
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                            .fixedSize()
                    }
                }
                if isCurrent, let renews = renewalText(for: product) {
                    Text(renews)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.green)
                } else {
                    Text(product.tagline)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: SBSpacing.sm)

            if isCurrent {
                Text("Mevcut plan")
                    .font(SBTypography.labelSmall)
                    .foregroundStyle(SBColors.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(SBColors.green.opacity(0.12), in: Capsule())
            } else {
                SBButton(
                    actionLabel,
                    variant: isUpgrade || active == nil ? .primary : .secondary,
                    size: .small,
                    isLoading: isBuying,
                    isDisabled: skProduct == nil
                ) {
                    // Downgrades don't apply immediately (App Store rule) — confirm
                    // the period-end timing first so the user isn't surprised by the
                    // unchanged quota / Apple's "already subscribed" sheet.
                    if active != nil && !isUpgrade {
                        pendingDowngrade = product
                    } else {
                        Task { await purchaseStorage(product) }
                    }
                }
            }
        }
        .padding(SBSpacing.sm)
        .background(SBColors.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: isCurrent ? 1.5 : 1))
    }

    private func byteString(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
    }

    /// Always show prices in Turkish Lira. Uses the live App Store price only when
    /// it is already in TRY (the real TR storefront); otherwise (e.g. a US sandbox
    /// test account) falls back to our TL label so the user never sees USD.
    private func tlPrice(_ product: Product?, fallback: String) -> String {
        guard let product else { return fallback }
        if product.priceFormatStyle.currencyCode == "TRY" {
            return product.displayPrice
        }
        return fallback
    }

    /// "Yenileme: 8 Tem 2026" line for the active plan, from its server expiry.
    private func renewalText(for product: SBStorageProduct) -> String? {
        guard let plan = storageStatus?.plans.first(where: { $0.productCode == product.rawValue }),
              let iso = plan.expiresAt,
              let date = parseISODate(iso) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM yyyy"
        return "Yenileme: \(formatter.string(from: date))"
    }

    private func parseISODate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func fetchStorageStatus() async {
        guard let client = await AuthBackend.shared.getClient() else { return }
        storageStatus = try? await DriveAPI(client: client).storageStatus()
    }

    /// Formatted end-of-period date of the active plan ("8 Temmuz 2026"), if known.
    private var activePlanEndDate: String? {
        guard let iso = storageStatus?.plans.first?.expiresAt,
              let date = parseISODate(iso) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    /// Confirmation copy shown before a downgrade so the user understands the
    /// App Store rule: the lower tier starts only when the current period ends.
    private func downgradeMessage(to product: SBStorageProduct) -> String {
        let current = activeStoragePlan?.displayName ?? "Mevcut paketin"
        if let end = activePlanEndDate {
            return "\(current) paketinden \(product.displayName) paketine geçiyorsun. "
                + "App Store kuralı gereği bu değişiklik hemen uygulanmaz: "
                + "\(current) paketin \(end) tarihine kadar devam eder, süresi dolunca "
                + "\(product.displayName) paketine otomatik geçilir. Şimdi ödeme alınmaz."
        }
        return "\(current) paketinden \(product.displayName) paketine geçiyorsun. "
            + "App Store kuralı gereği bu değişiklik mevcut dönem sonunda uygulanır; "
            + "o zamana kadar \(current) paketin devam eder. Şimdi ödeme alınmaz."
    }

    private func purchaseStorage(_ product: SBStorageProduct, isDowngrade: Bool = false) async {
        guard let skProduct = storeKit.product(id: product.productId) else {
            storageError = "Bu abonelik şu anda App Store'dan yüklenemedi. Tekrar deneyebilirsin."
            return
        }
        let endDate = activePlanEndDate
        let currentName = activeStoragePlan?.displayName ?? "Mevcut paketin"
        buyingStorageId = product.id
        storageError = nil
        storageInfo = nil
        do {
            try await storeKit.purchase(skProduct)
            if isDowngrade {
                // Downgrade is scheduled by Apple for the next renewal; the quota
                // does NOT change now, so don't claim it did.
                if let endDate {
                    storageInfo = "Plan değişikliğin alındı. \(currentName) paketin "
                        + "\(endDate) tarihine kadar devam edecek, ardından "
                        + "\(product.displayName) paketine geçilecek."
                } else {
                    storageInfo = "Plan değişikliğin alındı. Mevcut paketin dönem "
                        + "sonuna kadar devam edecek, ardından \(product.displayName) başlayacak."
                }
            } else {
                storageInfo = "Depolama aboneliğin etkinleşti. Kotan güncellendi."
            }
            await fetchStorageStatus()
        } catch SBStoreError.cancelled {
            // user cancelled — stay silent
        } catch SBStoreError.pending {
            storageInfo = SBStoreError.pending.errorDescription
        } catch {
            if isDowngrade {
                // A downgrade may already be scheduled (Apple's "already
                // subscribed" sheet) — reassure instead of showing a hard error.
                if let endDate {
                    storageInfo = "Plan değişikliğin zaten alınmış olabilir. "
                        + "\(currentName) paketin \(endDate) tarihine kadar devam eder, "
                        + "ardından \(product.displayName) başlar. App Store > Abonelikler'den kontrol edebilirsin."
                } else {
                    storageInfo = "Plan değişikliğin zaten alınmış olabilir. Mevcut paketin "
                        + "dönem sonunda \(product.displayName) paketine geçer. App Store > Abonelikler'den kontrol edebilirsin."
                }
            } else {
                storageError = error.localizedDescription.isEmpty
                    ? "Abonelik tamamlanamadı. Tekrar deneyebilirsin."
                    : error.localizedDescription
            }
        }
        buyingStorageId = nil
    }
}

// MARK: - MedasiCoinPackage

struct MedasiCoinPackage: Identifiable, Sendable {
    let id = UUID()
    let code: String
    let coin: Int
    let priceCents: Int
    let originalPriceCents: Int
    let title: String
    let description: String
    let currency: String
    let sortOrder: Int

    init(
        code: String,
        coin: Int,
        priceCents: Int,
        originalPriceCents: Int? = nil,
        title: String,
        description: String,
        currency: String,
        sortOrder: Int
    ) {
        self.code = code
        self.coin = coin
        self.priceCents = priceCents
        self.originalPriceCents = originalPriceCents ?? Int((Double(priceCents) / 0.9).rounded())
        self.title = title
        self.description = description
        self.currency = currency
        self.sortOrder = sortOrder
    }

    init(snapshot: StoreProductSnapshot) {
        self.init(
            code: snapshot.code,
            coin: snapshot.coin,
            priceCents: snapshot.priceCents,
            title: snapshot.title,
            description: snapshot.description,
            currency: snapshot.currency,
            sortOrder: snapshot.sortOrder
        )
    }

    /// App Store consumable product ID, derived from the backend `store_products.code`
    /// (e.g. "mc_10" → "tr.com.medasi.sourcebase.mc_10"). Using the code — not the coin
    /// amount — keeps IDs unique across packages that happen to grant the same MC.
    var appStoreProductId: String {
        "tr.com.medasi.sourcebase.\(code)"
    }

    /// Only consumable MC packs are sold via StoreKit. Subscriptions (weekly/monthly)
    /// remain on the web checkout flow and are filtered out of the in-app store.
    var isConsumableCoinPack: Bool {
        coin > 0 && !code.lowercased().contains("subscription")
    }

    var priceLabel: String {
        Self.priceLabel(cents: priceCents, currency: currency)
    }

    // SourceBase prices are always in Turkish Lira — display TL everywhere.
    var currencyDisplay: String { "TL" }

    private static func priceLabel(cents: Int, currency: String) -> String {
        guard cents > 0 else { return "Ücretsiz" }
        let amount = Double(cents) / 100.0
        let formatted = amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", amount)
            : String(format: "%.2f", amount)
        return "\(formatted) TL"
    }
}

#Preview {
    NavigationStack {
        StoreView()
            .environment(AppState.shared)
    }
}
