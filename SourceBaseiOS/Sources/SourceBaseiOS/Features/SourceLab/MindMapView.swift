import SwiftUI

struct MindMapView: View {
    var body: some View {
        SourceLabToolFlowView(
            title: "Zihin Haritası",
            subtitle: "Kavram ilişkilerini çıkar.",
            kind: .mindMap,
            outputLabel: "Zihin Haritası",
            icon: "point.3.connected.trianglepath.dotted",
            tint: SBColors.purple,
            controls: ["3 ana dal", "5 ana dal", "Klinik ilişki", "Tanı odaklı", "Kısa etiketler"],
            previewSections: ["Merkez", "Ana dallar", "Alt kavramlar", "Karıştırılanlar"]
        )
    }
}
