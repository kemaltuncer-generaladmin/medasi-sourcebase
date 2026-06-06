import SwiftUI

struct PlanView: View {
    var body: some View {
        SourceLabToolFlowView(
            title: "Öğrenme Planı",
            subtitle: "Kaynağı günlük plana çevir.",
            kind: .learningPlan,
            outputLabel: "Öğrenme Planı",
            icon: "calendar.badge.clock",
            tint: SBColors.green,
            controls: ["3 gün", "7 gün", "14 gün", "Günde 45 dk", "Günde 90 dk"],
            previewSections: ["Hedef", "Günlük bloklar", "Tekrar", "Son kontrol"]
        )
    }
}
