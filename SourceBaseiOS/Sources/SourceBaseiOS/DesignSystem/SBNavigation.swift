import SwiftUI

public extension View {
    /// Applies an inline navigation title display mode on iOS, and is a no-op on
    /// macOS where the modifier is unavailable. Keeps pushed detail screens from
    /// showing a large title that duplicates an in-content header.
    @ViewBuilder
    func sbInlineNavTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Gives the navigation bar an opaque, theme-matching background so scroll
    /// content (wallet cards, dense lists) doesn't ghost through a translucent
    /// bar. iOS-only; a no-op on macOS where `.navigationBar` placement is
    /// unavailable.
    @ViewBuilder
    func sbOpaqueNavBar() -> some View {
        #if os(iOS)
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(SBColors.page, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Uses a consistent leading back action on profile detail screens. Some
    /// flows are also valid root screens, so callers can hide it when needed.
    func sbBackButton(isVisible: Bool = true, action: @escaping () -> Void) -> some View {
        self
            .navigationBarBackButtonHidden(isVisible)
            .toolbar {
                if isVisible {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: action) {
                            Label("Geri", systemImage: "chevron.left")
                                .font(SBTypography.labelSmall)
                                .foregroundStyle(SBColors.blue)
                        }
                    }
                }
            }
    }
}
