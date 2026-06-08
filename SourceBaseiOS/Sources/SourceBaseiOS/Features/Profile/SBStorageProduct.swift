import Foundation

/// App Store storage subscription tiers (auto-renewable monthly).
///
/// These form a single **subscription cascade**: all three products must live in
/// ONE subscription group in App Store Connect, so a user has at most one active
/// tier and Apple handles upgrade/downgrade/crossgrade between them. The server
/// quota = free 25 GB + the (single) active tier's bonus.
///
/// Product IDs follow the MC-package scheme `tr.com.medasi.sourcebase.<code>`,
/// and `<code>` MUST match the server `STORAGE_PRODUCTS` map. `allCases` is in
/// ascending tier order (10 → 25 → 50).
enum SBStorageProduct: String, CaseIterable, Identifiable {
    case gb15 = "storage_15gb_monthly"
    case gb25 = "storage_25gb_monthly"
    case gb50 = "storage_50gb_monthly"

    static let bundlePrefix = "tr.com.medasi.sourcebase."

    var id: String { rawValue }
    var productId: String { Self.bundlePrefix + rawValue }

    static var allProductIds: Set<String> { Set(allCases.map(\.productId)) }

    /// True for any App Store product id that represents a storage subscription.
    static func isStorageProductId(_ id: String) -> Bool {
        id.contains("storage_") || allProductIds.contains(id)
    }

    static func from(productId: String) -> SBStorageProduct? {
        allCases.first { $0.productId == productId }
    }

    /// Tier size in GB; doubles as the ordering key for the cascade ladder.
    var gigabytes: Int {
        switch self {
        case .gb15: return 15
        case .gb25: return 25
        case .gb50: return 50
        }
    }

    /// Bonus bytes this tier grants (binary GB, matches the server map).
    var bonusBytes: Int { gigabytes * 1024 * 1024 * 1024 }

    var gbLabel: String { "+\(gigabytes) GB" }

    /// Shown when StoreKit hasn't loaded the live App Store price yet. The real
    /// price still comes from App Store Connect; keep these in sync as a hint.
    var fallbackPriceLabel: String {
        switch self {
        case .gb15: return "40 TL/ay"
        case .gb25: return "60 TL/ay"
        case .gb50: return "110 TL/ay"
        }
    }

    var tagline: String {
        switch self {
        case .gb15: return "Ek kaynak ve çıktılar için rahat alan."
        case .gb25: return "Düzenli çalışan öğrenciler için bol alan."
        case .gb50: return "Yoğun arşiv ve üretim için en geniş alan."
        }
    }

    var icon: String {
        switch self {
        case .gb15: return "externaldrive"
        case .gb25: return "externaldrive.fill"
        case .gb50: return "internaldrive.fill"
        }
    }
}
