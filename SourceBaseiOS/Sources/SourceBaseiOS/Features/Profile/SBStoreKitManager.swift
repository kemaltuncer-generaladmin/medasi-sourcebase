import StoreKit
import OSLog

// MARK: - StoreKit 2 IAP Manager
// Consumable coin package purchases for SourceBase.
// Product ID scheme: tr.com.medasi.sourcebase.<store_products.code> (e.g. ".mc_10").
// Derived from the backend package `code`, not the coin amount, so packages that grant
// the same MC stay unique. See MedasiCoinPackage.appStoreProductId in StoreView.swift.

@Observable
@MainActor
final class SBStoreKitManager {
    static let shared = SBStoreKitManager()
    private static let logger = Logger(subsystem: "tr.com.medasi.sourcebase", category: "store")

    private(set) var products: [Product] = []
    private(set) var isPurchasing = false

    // (transactionId, productId, jwsRepresentation) → new wallet balance
    // Set once at app launch; used by both purchase() and the background updates listener.
    var onRedeem: ((String, String, String) async throws -> Double)?

    private var transactionListenerTask: Task<Void, Never>?
    private var redeemedTransactionIds = Set<String>()
    private var redeemingTransactionIds = Set<String>()

    private init() {}

    // Start listening for App Store updates (promotions, restores, Ask-to-Buy approvals).
    func startListening() {
        guard transactionListenerTask == nil else { return }
        transactionListenerTask = Task(priority: .background) { [weak self] in
            for await verification in Transaction.updates {
                guard let self, !Task.isCancelled else { break }
                await self.handleTransactionUpdate(verification)
            }
        }
    }

    func stopListening() {
        transactionListenerTask?.cancel()
        transactionListenerTask = nil
    }

    // Load StoreKit products for the given set of product IDs.
    func loadProducts(ids: Set<String>) async throws {
        do {
            let fetched = try await Product.products(for: ids)
            products = fetched.sorted { $0.price < $1.price }
            Self.logger.info("storekit products loaded requested=\(ids.count, privacy: .public) received=\(fetched.count, privacy: .public)")
        } catch {
            Self.logger.error("storekit product load failed requested=\(ids.count, privacy: .public) error=\(String(describing: error), privacy: .private)")
            throw error
        }
    }

    // Find a loaded Product that matches the given product ID.
    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    // Perform a purchase. Throws SBStoreError.cancelled for user cancellations
    // (caller should suppress the error UI for cancellations).
    // Does NOT call transaction.finish() until backend redeem succeeds.
    func purchase(_ product: Product) async throws {
        guard !isPurchasing else { throw SBStoreError.alreadyProcessing }
        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            try await redeemAndFinish(
                transaction,
                productId: product.id,
                jws: verification.jwsRepresentation,
                source: "purchase"
            )
        case .userCancelled:
            Self.logger.info("storekit purchase cancelled product=\(product.id, privacy: .public)")
            throw SBStoreError.cancelled
        case .pending:
            Self.logger.info("storekit purchase pending product=\(product.id, privacy: .public)")
            throw SBStoreError.pending
        @unknown default:
            Self.logger.error("storekit purchase unknown result product=\(product.id, privacy: .public)")
            throw SBStoreError.cancelled
        }
    }

    // Restore consumable purchases (App Store requirement; consumables don't actually restore
    // but AppStore.sync() satisfies the restore button requirement).
    func restore() async throws {
        do {
            try await AppStore.sync()
            Self.logger.info("storekit restore sync requested")
        } catch {
            Self.logger.error("storekit restore sync failed error=\(String(describing: error), privacy: .private)")
            throw error
        }
    }

    // MARK: - Internal

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified:
            Self.logger.error("storekit verification failed")
            throw SBStoreError.verificationFailed
        }
    }

    private func handleTransactionUpdate(_ verification: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(verification)
            try await redeemAndFinish(
                transaction,
                productId: transaction.productID,
                jws: verification.jwsRepresentation,
                source: "updates"
            )
        } catch SBStoreError.alreadyProcessing {
            Self.logger.info("storekit transaction update already processing")
        } catch {
            Self.logger.error("storekit transaction update deferred error=\(String(describing: error), privacy: .private)")
        }
    }

    private func redeemAndFinish(
        _ transaction: Transaction,
        productId: String,
        jws: String,
        source: String
    ) async throws {
        let transactionId = String(transaction.id)
        guard !redeemedTransactionIds.contains(transactionId) else {
            Self.logger.info("storekit transaction already redeemed source=\(source, privacy: .public) product=\(productId, privacy: .public) transaction=\(transactionId, privacy: .private)")
            return
        }
        guard !redeemingTransactionIds.contains(transactionId) else {
            Self.logger.info("storekit transaction redeem in-flight source=\(source, privacy: .public) product=\(productId, privacy: .public) transaction=\(transactionId, privacy: .private)")
            throw SBStoreError.alreadyProcessing
        }
        guard let redeem = onRedeem else {
            Self.logger.error("storekit redeem unavailable source=\(source, privacy: .public) product=\(productId, privacy: .public) transaction=\(transactionId, privacy: .private)")
            throw SBStoreError.redemptionUnavailable
        }

        redeemingTransactionIds.insert(transactionId)
        defer { redeemingTransactionIds.remove(transactionId) }

        do {
            _ = try await redeem(transactionId, productId, jws)
            await transaction.finish()
            redeemedTransactionIds.insert(transactionId)
            Self.logger.info("storekit transaction redeemed source=\(source, privacy: .public) product=\(productId, privacy: .public) transaction=\(transactionId, privacy: .private)")
        } catch {
            Self.logger.error("storekit redeem failed source=\(source, privacy: .public) product=\(productId, privacy: .public) transaction=\(transactionId, privacy: .private) error=\(String(describing: error), privacy: .private)")
            throw SBStoreError.redemptionFailed
        }
    }
}

enum SBStoreError: LocalizedError {
    case cancelled
    case pending
    case verificationFailed
    case redemptionUnavailable
    case redemptionFailed
    case alreadyProcessing
    case unknown

    var errorDescription: String? {
        switch self {
        case .cancelled: return nil
        case .pending: return "Satın alma onay bekliyor (Ask to Buy). Onaylandığında bakiyen güncellenecek."
        case .verificationFailed: return "Satın alma Apple tarafından doğrulanamadı."
        case .redemptionUnavailable: return "Satın alma doğrulandı ancak oturum bulunamadı. Uygulamayı açıp tekrar dene."
        case .redemptionFailed: return "Satın alma doğrulandı ancak bakiye güncellemesi tamamlanamadı. Uygulamayı açık tutup tekrar kontrol et."
        case .alreadyProcessing: return "Satın alma zaten işleniyor. Onay tamamlanınca bakiye yenilenecek."
        case .unknown: return "Bilinmeyen satın alma durumu."
        }
    }
}
