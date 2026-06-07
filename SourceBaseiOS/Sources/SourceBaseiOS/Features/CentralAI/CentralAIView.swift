import SwiftUI

struct CentralAIView: View {
    var body: some View {
        ScrollView {
            Text("Yakında burada olacak.")
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SBSpacing.lg)
                .sbFloatingTabContentPadding()
                .sbReadableWidth(920)
        }
        .sbPageBackground()
        .navigationTitle("MedasiChat")
        .sbOpaqueNavBar()
    }
}

#Preview {
    NavigationStack {
        CentralAIView()
    }
}
