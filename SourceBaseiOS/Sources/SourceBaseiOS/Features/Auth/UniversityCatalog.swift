import Foundation

enum UniversityCatalog {
    static let all: [String] = [
        "Acıbadem Mehmet Ali Aydınlar Üniversitesi",
        "Ankara Üniversitesi",
        "Atatürk Üniversitesi",
        "Başkent Üniversitesi",
        "Bezmialem Vakıf Üniversitesi",
        "Cerrahpaşa Tıp Fakültesi",
        "Dokuz Eylül Üniversitesi",
        "Ege Üniversitesi",
        "Erciyes Üniversitesi",
        "Gazi Üniversitesi",
        "Hacettepe Üniversitesi",
        "İstanbul Medipol Üniversitesi",
        "İstanbul Üniversitesi",
        "Koç Üniversitesi",
        "Marmara Üniversitesi",
        "Ondokuz Mayıs Üniversitesi",
        "Sağlık Bilimleri Üniversitesi",
        "Selçuk Üniversitesi",
        "Trakya Üniversitesi",
        "Uludağ Üniversitesi",
        "Yeditepe Üniversitesi"
    ]

    static func matches(_ query: String) -> [String] {
        let normalized = query
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return Array(all.prefix(8)) }
        return all.filter {
            $0.folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .contains(normalized)
        }
    }
}
