import SwiftUI

struct PodcastView: View {
    var body: some View {
        SourceLabToolFlowView(
            title: "Dinleme Tekrarı",
            subtitle: "Kaynağı yolda dinlenecek konu anlatımına çevir.",
            kind: .podcast,
            outputLabel: "Dinleme tekrarı",
            icon: "waveform",
            tint: SBColors.purple,
            controls: ["Tek anlatıcı", "İki anlatıcı", "8 dk", "15 dk", "Sakin"],
            previewSections: ["Kısa giriş", "Kavram anlatımı", "Klinik örnek", "Son tekrar soruları"]
        )
    }
}
