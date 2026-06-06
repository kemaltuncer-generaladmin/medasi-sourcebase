import SwiftUI

public enum SBTypography {
    // MARK: - Display
    public static let display1 = Font.system(.largeTitle, design: .default).weight(.heavy)
    public static let display2 = Font.system(.largeTitle, design: .default).weight(.heavy)

    // MARK: - Heading
    public static let heading1 = Font.system(.title, design: .default).weight(.bold)
    public static let heading2 = Font.system(.title2, design: .default).weight(.bold)
    public static let heading3 = Font.system(.title3, design: .default).weight(.bold)

    // MARK: - Title
    public static let titleLarge = Font.system(.title2, design: .default).weight(.semibold)
    public static let titleMedium = Font.system(.headline, design: .default).weight(.semibold)
    public static let titleSmall = Font.system(.subheadline, design: .default).weight(.semibold)

    // MARK: - Body
    public static let bodyLarge = Font.system(.title3, design: .default)
    public static let bodyMedium = Font.system(.body, design: .default)
    public static let bodySmall = Font.system(.callout, design: .default)

    // MARK: - Label
    public static let labelLarge = Font.system(.body, design: .default).weight(.semibold)
    public static let labelMedium = Font.system(.callout, design: .default).weight(.semibold)
    public static let labelSmall = Font.system(.caption, design: .default).weight(.semibold)

    // MARK: - Caption
    public static let caption = Font.system(.caption2, design: .default).weight(.medium)
}

private struct SBScaledFontModifier: ViewModifier {
    let weight: Font.Weight
    let design: Font.Design

    @ScaledMetric private var scaledSize: CGFloat

    init(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) {
        self.weight = weight
        self.design = design
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design))
    }
}

public extension View {
    func sbScaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(SBScaledFontModifier(size: size, weight: weight, design: design, relativeTo: textStyle))
    }
}
