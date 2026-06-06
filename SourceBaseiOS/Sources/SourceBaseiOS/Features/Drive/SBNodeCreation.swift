import SwiftUI

// MARK: - Hex color helper

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
        } else {
            r = 0.039; g = 0.357; b = 1.0 // SBColors.blue fallback
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Curated palettes for course / section symbols

enum SBNodePalette {
    static let symbols: [String] = [
        "book.closed", "brain.head.profile", "heart.text.square", "cross.case",
        "stethoscope", "lungs", "pills", "flask",
        "function", "list.bullet.rectangle", "graduationcap", "atom",
        "waveform.path.ecg", "bandage", "eye", "folder"
    ]

    /// (hex, swatch color) — kept in sync with SBColors.
    static let colors: [String] = [
        "#0A5BFF", "#08C7D6", "#7B3FF2", "#12AE55",
        "#FF6B13", "#FF3B3B", "#07123F", "#0FA3A3"
    ]

    static let defaultSymbol = "book.closed"
    static let defaultColor = "#0A5BFF"
}

// MARK: - Reusable create sheet (course + section)

struct SBCreateNodeSheet: View {
    let heading: String
    let placeholder: String
    let confirmLabel: String
    let onCreate: (_ title: String, _ iconName: String, _ colorHex: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedSymbol = SBNodePalette.defaultSymbol
    @State private var selectedColor = SBNodePalette.defaultColor
    @FocusState private var nameFocused: Bool

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let symbolColumns = Array(repeating: GridItem(.flexible(), spacing: SBSpacing.sm), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SBSpacing.xl) {
                    previewCard
                    nameField
                    symbolPicker
                    colorPicker
                }
                .padding(SBSpacing.lg)
                .sbReadableWidth(560)
            }
            .sbPageBackground()
            .navigationTitle(heading)
            .sbInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmLabel) {
                        onCreate(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            selectedSymbol,
                            selectedColor
                        )
                        dismiss()
                    }
                    .disabled(!canCreate)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { nameFocused = true }
        }
    }

    private var color: Color { Color(hex: selectedColor) }

    private var previewCard: some View {
        HStack(spacing: SBSpacing.md) {
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.14))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: selectedSymbol)
                        .sbScaledFont(size: 24, weight: .semibold)
                        .foregroundStyle(color)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title.isEmpty ? placeholder : title)
                    .font(SBTypography.titleMedium)
                    .foregroundStyle(title.isEmpty ? SBColors.softText : SBColors.navy)
                    .lineLimit(1)
                Text("Önizleme")
                    .font(SBTypography.caption)
                    .foregroundStyle(SBColors.muted)
            }
            Spacer()
        }
        .padding(SBSpacing.md)
        .background(SBColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SBColors.softLine, lineWidth: 1))
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Text("Ad")
                .font(SBTypography.labelMedium)
                .foregroundStyle(SBColors.navy)
            TextField(placeholder, text: $title)
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.navy)
                .focused($nameFocused)
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif
                .submitLabel(.done)
                .padding(.horizontal, SBSpacing.lg)
                .frame(height: 52)
                .background(SBColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(nameFocused ? SBColors.blue : SBColors.line, lineWidth: nameFocused ? 1.5 : 1)
                )
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Text("Sembol")
                .font(SBTypography.labelMedium)
                .foregroundStyle(SBColors.navy)
            LazyVGrid(columns: symbolColumns, spacing: SBSpacing.sm) {
                ForEach(SBNodePalette.symbols, id: \.self) { symbol in
                    let isSelected = symbol == selectedSymbol
                    Button {
                        selectedSymbol = symbol
                    } label: {
                        Image(systemName: symbol)
                            .sbScaledFont(size: 20, weight: .medium)
                            .foregroundStyle(isSelected ? color : SBColors.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(isSelected ? color.opacity(0.14) : SBColors.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? color.opacity(0.5) : SBColors.softLine, lineWidth: isSelected ? 1.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sembol \(symbol)")
                }
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Text("Renk")
                .font(SBTypography.labelMedium)
                .foregroundStyle(SBColors.navy)
            HStack(spacing: SBSpacing.md) {
                ForEach(SBNodePalette.colors, id: \.self) { hex in
                    let swatch = Color(hex: hex)
                    Button {
                        selectedColor = hex
                    } label: {
                        Circle()
                            .fill(swatch)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Circle()
                                    .stroke(SBColors.white, lineWidth: selectedColor == hex ? 3 : 0)
                            )
                            .overlay(
                                Circle()
                                    .stroke(swatch.opacity(selectedColor == hex ? 1 : 0.2), lineWidth: 2)
                            )
                            .shadow(color: swatch.opacity(selectedColor == hex ? 0.4 : 0), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Renk \(hex)")
                }
                Spacer()
            }
        }
    }
}
