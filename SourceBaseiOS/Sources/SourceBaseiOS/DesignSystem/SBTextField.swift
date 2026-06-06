import SwiftUI
#if canImport(UIKit)
import UIKit

public struct SBTextField: View {
    let icon: String
    let hint: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let onSubmit: (() -> Void)?

    @State private var isSecureVisible = false
    @FocusState private var isFocused: Bool

    public init(
        icon: String,
        hint: String,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.hint = hint
        self._text = text
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: icon)
                .sbScaledFont(size: 18, weight: .medium)
                .foregroundStyle(SBColors.blue)
                .frame(width: 24)

            Group {
                if isSecure && !isSecureVisible {
                    SecureField(hint, text: $text)
                        .textContentType(textContentType ?? .password)
                } else {
                    TextField(hint, text: $text)
                        .textContentType(textContentType)
                }
            }
            .font(SBTypography.bodyMedium)
            .foregroundStyle(SBColors.navy)
            .keyboardType(keyboardType)
            .focused($isFocused)
            .onSubmit { onSubmit?() }

            if isSecure {
                Button {
                    isSecureVisible.toggle()
                } label: {
                    Image(systemName: isSecureVisible ? "eye.slash" : "eye")
                        .sbScaledFont(size: 18)
                        .foregroundStyle(SBColors.muted)
                }
            }
        }
        .padding(.horizontal, SBSpacing.lg)
        .frame(height: 52)
        .background(SBColors.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? SBColors.blue : SBColors.line, lineWidth: isFocused ? 1.5 : 1)
        )
        .shadow(color: SBColors.navy.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        SBTextField(
            icon: "envelope",
            hint: "E-posta",
            text: .constant(""),
            keyboardType: .emailAddress,
            textContentType: .emailAddress
        )

        SBTextField(
            icon: "lock",
            hint: "Şifre",
            text: .constant(""),
            isSecure: true,
            textContentType: .password
        )
    }
    .padding()
    .sbPageBackground()
}
#endif
