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

    static func symbolLabel(for symbol: String) -> String {
        switch symbol {
        case "book.closed": return "Kitap simgesi"
        case "brain.head.profile": return "Beyin simgesi"
        case "heart.text.square": return "Kalp notu simgesi"
        case "cross.case": return "Sağlık çantası simgesi"
        case "stethoscope": return "Stetoskop simgesi"
        case "lungs": return "Akciğer simgesi"
        case "pills": return "İlaç simgesi"
        case "flask": return "Laboratuvar simgesi"
        case "function": return "Formül simgesi"
        case "list.bullet.rectangle": return "Liste simgesi"
        case "graduationcap": return "Mezuniyet simgesi"
        case "atom": return "Atom simgesi"
        case "waveform.path.ecg": return "EKG simgesi"
        case "bandage": return "Bandaj simgesi"
        case "eye": return "Göz simgesi"
        case "folder": return "Klasör simgesi"
        default: return "Sembol"
        }
    }

    static func colorLabel(for hex: String) -> String {
        switch hex.uppercased() {
        case "#0A5BFF": return "Mavi renk"
        case "#08C7D6": return "Turkuaz renk"
        case "#7B3FF2": return "Mor renk"
        case "#12AE55": return "Yeşil renk"
        case "#FF6B13": return "Turuncu renk"
        case "#FF3B3B": return "Kırmızı renk"
        case "#07123F": return "Lacivert renk"
        case "#0FA3A3": return "Cam göbeği renk"
        default: return "Renk"
        }
    }
}

// MARK: - Reusable create sheet (course + section)

struct SBCreateNodeSheet: View {
    let heading: String
    let placeholder: String
    let confirmLabel: String
    let onCreate: (_ title: String, _ iconName: String, _ colorHex: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var title = ""
    @State private var selectedSymbol = SBNodePalette.defaultSymbol
    @State private var selectedColor = SBNodePalette.defaultColor
    @FocusState private var nameFocused: Bool

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SBSpacing.lg) {
                    previewCard
                    nameField
                    symbolPicker
                    colorPicker
                }
                .padding(SBSpacing.lg)
                .sbReadableWidth(560)
            }
            .sbPageBackground(tone: .warm)
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
    private var isCompact: Bool { horizontalSizeClass == .compact }

    private var symbolColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: SBSpacing.sm), count: isCompact ? 5 : 4)
    }

    private var previewCard: some View {
        HStack(spacing: SBSpacing.md) {
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.14))
                .frame(width: isCompact ? 48 : 56, height: isCompact ? 48 : 56)
                .overlay(
                    Image(systemName: selectedSymbol)
                        .sbScaledFont(size: isCompact ? 21 : 24, weight: .semibold)
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
            if isCompact {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SBSpacing.sm) {
                        ForEach(SBNodePalette.symbols, id: \.self) { symbol in
                            symbolButton(symbol)
                                .frame(width: 50)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                LazyVGrid(columns: symbolColumns, spacing: SBSpacing.sm) {
                    ForEach(SBNodePalette.symbols, id: \.self) { symbol in
                        symbolButton(symbol)
                    }
                }
            }
        }
    }

    private func symbolButton(_ symbol: String) -> some View {
        let isSelected = symbol == selectedSymbol
        return Button {
            selectedSymbol = symbol
        } label: {
            Image(systemName: symbol)
                .sbScaledFont(size: 20, weight: .medium)
                .foregroundStyle(isSelected ? color : SBColors.muted)
                .frame(maxWidth: .infinity)
                .frame(height: isCompact ? 48 : 52)
                .background(isSelected ? color.opacity(0.14) : SBColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? color.opacity(0.5) : SBColors.softLine, lineWidth: isSelected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(SBNodePalette.symbolLabel(for: symbol))
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            Text("Renk")
                .font(SBTypography.labelMedium)
                .foregroundStyle(SBColors.navy)
            ScrollView(.horizontal, showsIndicators: false) {
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
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(SBNodePalette.colorLabel(for: hex))
                        .accessibilityValue(selectedColor == hex ? "Seçili" : "Seçili değil")
                    }
                }
            }
        }
    }
}
