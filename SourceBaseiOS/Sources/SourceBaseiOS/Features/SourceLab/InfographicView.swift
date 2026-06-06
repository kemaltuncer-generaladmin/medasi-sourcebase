import SwiftUI

struct InfographicView: View {
    var body: some View {
        SourceLabToolFlowView(
            title: "İnfografik",
            subtitle: "Kaynağı tek bakışta hatırlanacak görsel özete çevir.",
            kind: .infographic,
            outputLabel: "İnfografik",
            icon: "chart.bar.doc.horizontal",
            tint: SBColors.cyan,
            controls: ["Klinik", "Sınav", "Dikey", "Kare", "Yoğun", "Sade"],
            previewSections: ["Canlı görsel", "Ana mesaj", "5+ bilgi bloğu", "Kırmızı bayrak", "Hızlı kontrol", "Kaynak notu"]
        )
    }
}
